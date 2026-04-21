import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';
import '../database_service.dart';

class ScheduleDb {
  // ── LỊCH HỌC ─────────────────────────────

  static Future<void> saveLichHoc(List<LichHoc> list,
      {int? hocKy, String? namHoc}) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      // KHÔNG xóa - chỉ insert-or-ignore để giữ data cũ
      // Chỉ xóa nếu có dòng NEW (khác về thời gian, phòng, etc.) với cùng course
      print(
          '💾 [DB] Saving ${list.length} lich hoc records (append-not-overwrite mode)');

      int inserted = 0, skipped = 0;
      for (final item in list) {
        // Check if record already exists by checking: ten_hoc_phan + ten_lop_tin_chi + thoi_gian
        final existing = await txn.query('lich_hoc',
            where:
                'ten_hoc_phan = ? AND ten_lop_tin_chi = ? AND thoi_gian = ? AND hoc_ky = ? AND nam_hoc = ?',
            whereArgs: [
              item.tenHocPhan,
              item.tenLopTinChi,
              item.thoiGian,
              item.hocKy,
              item.namHoc
            ],
            limit: 1);

        if (existing.isEmpty) {
          // New record - insert
          await txn.insert('lich_hoc', item.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        } else {
          skipped++;
        }
      }
      print('💾 [DB] Saved: inserted=$inserted, skipped=$skipped');
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

  // ── LỊCH THI ─────────────────────────────

  static Future<void> saveLichThi(List<LichThi> list,
      {int? hocKy, String? namHoc}) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      // KHÔNG xóa - chỉ insert-or-ignore để giữ data cũ
      print(
          '💾 [DB] Saving ${list.length} lich thi records (append-not-overwrite mode)');

      int inserted = 0, skipped = 0;
      for (final item in list) {
        // Check if record already exists by: ma_hoc_phan + ngay_thi + ca_thi
        final existing = await txn.query('lich_thi',
            where:
                'ma_hoc_phan = ? AND ngay_thi = ? AND ca_thi = ? AND hoc_ky = ? AND nam_hoc = ?',
            whereArgs: [
              item.maMonHoc,
              item.ngayThi,
              item.caThi,
              item.hocKy,
              item.namHoc
            ],
            limit: 1);

        if (existing.isEmpty) {
          await txn.insert('lich_thi', item.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        } else {
          skipped++;
        }
      }
      print('💾 [DB] Saved: inserted=$inserted, skipped=$skipped');
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
}
