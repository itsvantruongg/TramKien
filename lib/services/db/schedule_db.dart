import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';
import '../database_service.dart';

class ScheduleDb {
  /// Kiểm tra xem có bản ghi SQLite nào mang fetched_app_version khác với phiên bản hiện tại (hoặc NULL) hay không. (B2)
  static Future<bool> needsReconcile(String currentAppVersion,
      {Database? db}) async {
    try {
      final d = db ?? await DatabaseService.db;
      final lichHocRows = await d.query(
        'lich_hoc',
        columns: ['fetched_app_version'],
        where:
            'is_manual = 0 AND (fetched_app_version IS NULL OR fetched_app_version != ?)',
        whereArgs: [currentAppVersion],
        limit: 1,
      );
      if (lichHocRows.isNotEmpty) return true;

      final lichThiRows = await d.query(
        'lich_thi',
        columns: ['fetched_app_version'],
        where:
            'is_manual = 0 AND (fetched_app_version IS NULL OR fetched_app_version != ?)',
        whereArgs: [currentAppVersion],
        limit: 1,
      );
      return lichThiRows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── LỊCH HỌC ─────────────────────────────

  /// Upsert lịch học (Bug 6 fix): không xóa trắng scope trước khi insert.
  /// Dùng ConflictAlgorithm.replace + UNIQUE INDEX để update đúng record.
  /// Khi [softDeleteAfter] == true (chỉ khi fetch [complete] == true),
  /// xóa các record không còn xuất hiện trong lần fetch này (stale records).
  static Future<void> saveLichHoc(
    List<LichHoc> list, {
    bool softDeleteAfter = false,
    DatabaseExecutor? db,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const appVersion = DatabaseService.currentAppVersion;

    // Cần Database instance để gọi .transaction()
    final dbInstance = (db is Database) ? db : await DatabaseService.db;

    await dbInstance.transaction((txn) async {
      int upserted = 0;
      for (final item in list) {
        final map = item.toMap();
        map['fetched_app_version'] = appVersion;
        map['synced_at'] = nowMs;
        map['last_seen_at'] = nowMs; // ← dùng để detect stale records
        // INSERT OR REPLACE hoạt động đúng nhờ UNIQUE INDEX (Migration v17)
        await txn.insert('lich_hoc', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        upserted++;
      }
      print('💾 [DB] saveLichHoc upsert: $upserted records');

      if (softDeleteAfter && list.isNotEmpty) {
        // Nhóm theo scope để soft-delete per (hocKy, namHoc, dotHoc)
        final scopes = <({int hocKy, String namHoc, int dotHoc})>{};
        for (final item in list) {
          scopes
              .add((hocKy: item.hocKy, namHoc: item.namHoc, dotHoc: item.dotHoc));
        }
        int deleted = 0;
        for (final s in scopes) {
          // ✅ Truyền txn (DatabaseExecutor) — KHÔNG truyền dbInstance
          // Truyền dbInstance sẽ deadlock vì dbInstance đang locked bởi transaction này
          deleted += await softDeleteStaleLichHoc(
            hocKy: s.hocKy,
            namHoc: s.namHoc,
            dotHoc: s.dotHoc,
            syncedAt: nowMs,
            db: txn,
          );
        }
        if (deleted > 0) {
          print('🗑️ [DB] soft-delete lich_hoc: $deleted stale records (is_manual=0)');
        }
      }
    });
  }

  /// Xóa các record lịch học không còn được API trả về (last_seen_at < syncedAt).
  /// Nhận [DatabaseExecutor?] để dùng được cả trong lẫn ngoài transaction.
  /// [!IMPORTANT] Luôn loại trừ is_manual = 1 (môn user tự nhập).
  static Future<int> softDeleteStaleLichHoc({
    required int hocKy,
    required String namHoc,
    required int dotHoc,
    required int syncedAt,
    DatabaseExecutor? db,
  }) async {
    final d = db ?? await DatabaseService.db;
    return d.delete(
      'lich_hoc',
      where: 'hoc_ky = ? AND nam_hoc = ? AND dot_hoc = ? '
          'AND is_manual = 0 '
          'AND (last_seen_at IS NULL OR last_seen_at < ?)',
      whereArgs: [hocKy, namHoc, dotHoc, syncedAt],
    );
  }

  static Future<List<LichHoc>> getLichHoc(
      {int? hocKy, String? namHoc, int? dotHoc}) async {
    final d = await DatabaseService.db;
    String? where;
    List<Object?>? args;

    if (hocKy != null && namHoc != null) {
      if (dotHoc != null) {
        where = 'hoc_ky = ? AND nam_hoc = ? AND dot_hoc = ?';
        args = [hocKy, namHoc, dotHoc];
      } else {
        where = 'hoc_ky = ? AND nam_hoc = ?';
        args = [hocKy, namHoc];
      }
    }

    final rows = await d.query('lich_hoc',
        where: where, whereArgs: args, orderBy: 'thu ASC, tiet ASC');

    final result = rows.map(LichHoc.fromMap).toList();

    final filterStr = where ?? 'NONE';
    print('📚 [DB] getLichHoc($filterStr) → ${result.length} records');
    if (result.isNotEmpty && result.length <= 5) {
      for (int i = 0; i < result.length; i++) {
        final l = result[i];
        print(
            '  → [$i] ${l.tenHocPhan} | Thu: ${l.thu}(${l.thuSo}) | ${l.thoiGian} | Dot${l.dotHoc}');
      }
    }

    return result;
  }

  // Lịch học theo thứ trong tuần hiện tại
  static Future<List<LichHoc>> getLichHocHoiNay(
      int hocKy, String namHoc) async {
    final d = await DatabaseService.db;
    final rows = await d.query('lich_hoc',
        where: 'hoc_ky = ? AND nam_hoc = ?',
        whereArgs: [hocKy, namHoc],
        orderBy: 'thu ASC, tiet ASC');
    return rows.map(LichHoc.fromMap).toList();
  }

  static Future<void> updateLichHocNote(int id, String note) async {
    final d = await DatabaseService.db;
    await d.update('lich_hoc', {'note': note},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertManualLichHoc(LichHoc item) async {
    final d = await DatabaseService.db;
    await d.insert('lich_hoc', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── LỊCH THI ─────────────────────────────

  /// Upsert lịch thi (Bug 6 fix): không xóa trắng scope trước khi insert.
  /// Khi [softDeleteAfter] == true (fetch [complete] == true), xóa stale records.
  static Future<void> saveLichThi(
    List<LichThi> list, {
    bool softDeleteAfter = false,
    DatabaseExecutor? db,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const appVersion = DatabaseService.currentAppVersion;

    final dbInstance = (db is Database) ? db : await DatabaseService.db;

    await dbInstance.transaction((txn) async {
      int upserted = 0;
      for (final item in list) {
        final map = item.toMap();
        map['fetched_app_version'] = appVersion;
        map['synced_at'] = nowMs;
        map['last_seen_at'] = nowMs;
        await txn.insert('lich_thi', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        upserted++;
      }
      print('💾 [DB] saveLichThi upsert: $upserted records');

      if (softDeleteAfter && list.isNotEmpty) {
        final scopes = <({int hocKy, String namHoc})>{};
        for (final item in list) {
          scopes.add((hocKy: item.hocKy, namHoc: item.namHoc));
        }
        int deleted = 0;
        for (final s in scopes) {
          // ✅ Truyền txn (DatabaseExecutor), không phải dbInstance
          deleted += await softDeleteStaleLichThi(
            hocKy: s.hocKy,
            namHoc: s.namHoc,
            syncedAt: nowMs,
            db: txn,
          );
        }
        if (deleted > 0) {
          print('🗑️ [DB] soft-delete lich_thi: $deleted stale records (is_manual=0)');
        }
      }
    });
  }

  /// Xóa các record lịch thi không còn được API trả về.
  /// [!IMPORTANT] Luôn loại trừ is_manual = 1.
  static Future<int> softDeleteStaleLichThi({
    required int hocKy,
    required String namHoc,
    required int syncedAt,
    DatabaseExecutor? db,
  }) async {
    final d = db ?? await DatabaseService.db;
    return d.delete(
      'lich_thi',
      where: 'hoc_ky = ? AND nam_hoc = ? '
          'AND is_manual = 0 '
          'AND (last_seen_at IS NULL OR last_seen_at < ?)',
      whereArgs: [hocKy, namHoc, syncedAt],
    );
  }

  static Future<List<LichThi>> getLichThi({int? hocKy, String? namHoc}) async {
    final d = await DatabaseService.db;
    final rows = await d.query('lich_thi',
        where: hocKy != null ? 'hoc_ky = ? AND nam_hoc = ?' : null,
        whereArgs: hocKy != null ? [hocKy, namHoc] : null,
        orderBy: 'ngay_thi ASC');
    return rows.map(LichThi.fromMap).toList();
  }

  static Future<void> updateLichThiNote(int id, String note) async {
    final d = await DatabaseService.db;
    await d.update('lich_thi', {'note': note},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertManualLichThi(LichThi item) async {
    final d = await DatabaseService.db;
    await d.insert('lich_thi', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteManualLichHoc(int id) async {
    final d = await DatabaseService.db;
    await d
        .delete('lich_hoc', where: 'id = ? AND is_manual = 1', whereArgs: [id]);
  }

  static Future<void> deleteManualLichThi(int id) async {
    final d = await DatabaseService.db;
    await d
        .delete('lich_thi', where: 'id = ? AND is_manual = 1', whereArgs: [id]);
  }
}
