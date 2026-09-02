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

  static Future<void> saveLichHoc(
    List<LichHoc> list, {
    int? hocKy,
    String? namHoc,
    List<({int hocKy, String namHoc, int dotHoc})>? scopesToClear,
    bool clearScope = true,
    Database? db,
  }) async {
    final d = db ?? await DatabaseService.db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const appVersion = DatabaseService.currentAppVersion;

    await d.transaction((txn) async {
      if (clearScope) {
        final scopes = <({int hocKy, String namHoc, int dotHoc})>{};
        if (scopesToClear != null) {
          scopes.addAll(scopesToClear);
        }
        for (final item in list) {
          scopes.add(
              (hocKy: item.hocKy, namHoc: item.namHoc, dotHoc: item.dotHoc));
        }
        if (hocKy != null && namHoc != null && scopes.isEmpty) {
          for (int dot = 1; dot <= 8; dot++) {
            scopes.add((hocKy: hocKy, namHoc: namHoc, dotHoc: dot));
          }
        }

        int deletedCount = 0;
        for (final s in scopes) {
          final count = await txn.delete(
            'lich_hoc',
            where:
                'hoc_ky = ? AND nam_hoc = ? AND dot_hoc = ? AND is_manual = 0',
            whereArgs: [s.hocKy, s.namHoc, s.dotHoc],
          );
          deletedCount += count;
        }
        print(
            '🗑️ [DB] diff-delete lich_hoc: $deletedCount records cũ (is_manual=0) đã bị xóa ở ${scopes.length} scopes');
      }

      int inserted = 0;
      for (final item in list) {
        final map = item.toMap();
        map['fetched_app_version'] = appVersion;
        map['synced_at'] = nowMs;
        await txn.insert('lich_hoc', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        inserted++;
      }
      print('💾 [DB] saveLichHoc: inserted=$inserted records mới');
    });
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

  static Future<void> saveLichThi(
    List<LichThi> list, {
    int? hocKy,
    String? namHoc,
    List<({int hocKy, String namHoc})>? scopesToClear,
    bool clearScope = true,
    Database? db,
  }) async {
    final d = db ?? await DatabaseService.db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const appVersion = DatabaseService.currentAppVersion;

    await d.transaction((txn) async {
      if (clearScope) {
        final scopes = <({int hocKy, String namHoc})>{};
        if (scopesToClear != null) {
          scopes.addAll(scopesToClear);
        }
        for (final item in list) {
          scopes.add((hocKy: item.hocKy, namHoc: item.namHoc));
        }
        if (hocKy != null && namHoc != null && scopes.isEmpty) {
          scopes.add((hocKy: hocKy, namHoc: namHoc));
        }

        int deletedCount = 0;
        for (final s in scopes) {
          final count = await txn.delete(
            'lich_thi',
            where: 'hoc_ky = ? AND nam_hoc = ? AND is_manual = 0',
            whereArgs: [s.hocKy, s.namHoc],
          );
          deletedCount += count;
        }
        print(
            '🗑️ [DB] diff-delete lich_thi: $deletedCount records cũ (is_manual=0) đã bị xóa ở ${scopes.length} scopes');
      }

      int inserted = 0;
      for (final item in list) {
        final map = item.toMap();
        map['fetched_app_version'] = appVersion;
        map['synced_at'] = nowMs;
        await txn.insert('lich_thi', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        inserted++;
      }
      print('💾 [DB] saveLichThi: inserted=$inserted records mới');
    });
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
