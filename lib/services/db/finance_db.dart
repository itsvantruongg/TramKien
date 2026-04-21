import 'package:sqflite/sqflite.dart';
import '../database_service.dart';

class FinanceDb {
  // ── HỌC PHÍ ──────────────────────────────

  // Lưu payment_receipts
  static Future<void> savePaymentReceipts(
      List<Map<String, dynamic>> list) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      for (final item in list) {
        await txn.insert('payment_receipts', item,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // Lấy danh sách phiếu thu
  static Future<List<Map<String, Object?>>> getPaymentReceipts(
      {String? namHoc, int? hocKy}) async {
    final d = await DatabaseService.db;
    return d.query('payment_receipts',
        where: namHoc != null ? 'nam_hoc = ? AND hoc_ky = ?' : null,
        whereArgs: namHoc != null ? [namHoc, hocKy] : null,
        orderBy: 'nam_hoc DESC, hoc_ky DESC, ngay_thu DESC');
  }

  // Lấy chi tiết học phí theo phiếu
  static Future<List<Map<String, Object?>>> getFeeDetails(
      {String? soPhieu, String? namHoc, int? hocKy}) async {
    final d = await DatabaseService.db;
    if (soPhieu != null) {
      return d
          .query('fee_details', where: 'so_phieu = ?', whereArgs: [soPhieu]);
    }
    // Nếu không có filter → lấy TẤT CẢ
    if (namHoc == null && hocKy == null) {
      return d.query('fee_details', orderBy: 'nam_hoc DESC, hoc_ky DESC');
    }
    return d.query('fee_details',
        where: namHoc != null ? 'nam_hoc = ? AND hoc_ky = ?' : null,
        whereArgs: namHoc != null ? [namHoc, hocKy] : null,
        orderBy: 'nam_hoc DESC, hoc_ky DESC');
  }

  // ── CHI TIẾT HỌC PHÍ ──────────────────────
  static Future<void> saveFeeDetails(List<Map<String, dynamic>> list) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      // KHÔNG xóa - chỉ insert-or-ignore để giữ data cũ
      print(
          '💾 [DB] Saving ${list.length} fee_details records (append-not-overwrite mode)');

      int inserted = 0, skipped = 0;
      for (final raw in list) {
        // Check if record already exists by: so_phieu + ten_hoc_phan
        final existing = await txn.query('fee_details',
            where:
                'so_phieu = ? AND ten_hoc_phan = ? AND nam_hoc = ? AND hoc_ky = ?',
            whereArgs: [
              raw['so_phieu'],
              raw['ten_hoc_phan'],
              raw['nam_hoc'],
              raw['hoc_ky']
            ],
            limit: 1);

        if (existing.isEmpty) {
          await txn.insert(
              'fee_details',
              {
                'so_phieu': raw['so_phieu'],
                'ten_hoc_phan': raw['ten_hoc_phan'],
                'so_tien_phai_nop': raw['so_tien_phai_nop'],
                'so_tien_da_nop': raw['so_tien_da_nop'],
                'so_tien_thua_thieu': raw['so_tien_thua_thieu'],
                'trang_thai': raw['trang_thai'],
                'nam_hoc': raw['nam_hoc'],
                'hoc_ky': raw['hoc_ky'],
                'ngay_nop': raw['ngay_nop'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        } else {
          skipped++;
        }
      }
      print('💾 [DB] Saved: inserted=$inserted, skipped=$skipped');
    });
  }

  // Lưu fee_summary (upsert theo nam_hoc + hoc_ky)
  static Future<void> saveFeeSummary(Map<String, dynamic> summary) async {
    final d = await DatabaseService.db;
    await d.insert('fee_summary', summary,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Lấy tổng hợp học phí theo kỳ
  static Future<Map<String, Object?>?> getFeeSummary(
      String namHoc, int hocKy) async {
    final d = await DatabaseService.db;
    final rows = await d.query('fee_summary',
        where: 'nam_hoc = ? AND hoc_ky = ?', whereArgs: [namHoc, hocKy]);
    return rows.isEmpty ? null : rows.first;
  }

  // Tổng hợp tất cả kỳ (cho dashboard)
  static Future<List<Map<String, Object?>>> getAllFeeSummary() async {
    final d = await DatabaseService.db;
    return d.query('fee_summary', orderBy: 'nam_hoc DESC, hoc_ky DESC');
  }

  // Tổng số tiền còn thiếu toàn bộ
  static Future<double> getTongThieuHocPhi() async {
    final summaries = await getAllFeeSummary();
    return summaries.fold<double>(
        0.0, (s, row) => s + ((row['thua_thieu'] as num?)?.toDouble() ?? 0));
  }
}
