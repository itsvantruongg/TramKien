import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../hau_api_service.dart';
import '../database_service.dart';
import '../mock_data.dart';

class FinanceApi {
  // ── PARSE HELPER ──────────────────────────────────────────

  /// Parse tiền Việt Nam: "7.248.800,00 ₫" → 7248800.0
  static double _parseMoney(String s) {
    return double.tryParse(
          s
              .replaceAll('₫', '')
              .replaceAll('\u00a0', '') // non-breaking space
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .trim(),
        ) ??
        0.0;
  }

  /// Parse TẤT CẢ bảng trong HTML, hỗ trợ 2D grid (rowspan & colspan merged cells)
  static List<List<Map<String, String>>> _parseAllTables(String html) {
    final doc = HauApiService.parseHtml(html);
    final tables = doc.querySelectorAll('table');
    final result = <List<Map<String, String>>>[];

    for (final table in tables) {
      final headerCells = table.querySelectorAll('th');
      final headers = headerCells.isNotEmpty
          ? headerCells.map((e) => e.text.trim()).toList()
          : (table
                  .querySelector('tr')
                  ?.querySelectorAll('td')
                  .map((e) => e.text.trim())
                  .toList() ??
              []);

      if (headers.isEmpty) continue;

      final trs = table.querySelectorAll('tbody tr');
      if (trs.isEmpty) continue;

      final grid = HauApiService.parseTableGrid(trs);
      final rows = <Map<String, String>>[];

      for (final gridRow in grid) {
        if (gridRow.isEmpty) continue;
        final row = <String, String>{};
        for (var col = 0; col < headers.length && col < gridRow.length; col++) {
          row[headers[col]] = gridRow[col];
          row['_col$col'] = gridRow[col];
        }
        for (var col = 0; col < gridRow.length; col++) {
          row['_col$col'] = gridRow[col];
        }
        if (row.values.any((v) => v.isNotEmpty)) rows.add(row);
      }
      if (rows.isNotEmpty) result.add(rows);
    }
    return result;
  }

  // ── PUBLIC API ────────────────────────────────────────────

  /// Fetch và lưu trực tiếp vào DB (payment_receipts, fee_details, fee_summary)
  static Future<void> fetchAndSaveHocPhi() async {
    try {
      if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
        await MockData.populateFinance();
        return;
      }

      var r = await http
          .get(
            Uri.parse('${HauApiService.base}/TraCuuHocPhi/Index'),
            headers: HauApiService.authHeaders,
          )
          .timeout(const Duration(seconds: 30));

      HauApiService.saveCookies(r);
      if (r.statusCode != 200 ||
          HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
        if (HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          final reauthed = await HauApiService.reauthenticateIfNeeded();
          if (reauthed) {
            r = await http
                .get(
                  Uri.parse('${HauApiService.base}/TraCuuHocPhi/Index'),
                  headers: HauApiService.authHeaders,
                )
                .timeout(const Duration(seconds: 30));
            HauApiService.saveCookies(r);
          }
        }
        if (r.statusCode != 200 ||
            HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          debugPrint(
              '💰 [Finance] Session expired or invalid status: ${r.statusCode}');
          return;
        }
      }

      final allTables = _parseAllTables(r.body);
      debugPrint('💰 [Finance] Found ${allTables.length} tables in page');
      for (int i = 0; i < allTables.length; i++) {
        final headers = allTables[i].isEmpty
            ? []
            : allTables[i]
                .first
                .keys
                .where((k) => !k.startsWith('_col'))
                .toList();
        debugPrint(
            '  ├ Table[$i]: ${allTables[i].length} rows, headers: $headers');
      }

      // Dynamic content signature classification instead of hardcoded table array indices
      List<Map<String, String>>? tongQuanTable;
      List<Map<String, String>>? paymentReceiptsTable;
      List<Map<String, String>>? feeDetailsTable;

      for (final table in allTables) {
        if (table.isEmpty) continue;
        final headersStr =
            table.first.keys.join(' ') + ' ' + table.first.values.join(' ');

        if (tongQuanTable == null &&
            (headersStr.contains('Mực học phí') ||
                headersStr.contains('Mức học phí') ||
                headersStr.contains('Miễn giảm')) &&
            (headersStr.contains('Thừa thiếu') ||
                headersStr.contains('Thừa / thiếu') ||
                headersStr.contains('Số tiền đã nộp'))) {
          tongQuanTable = table;
          debugPrint(
              '💰 [Finance] Identified Summary Table by signature (${table.length} rows)');
        } else if (paymentReceiptsTable == null &&
            (headersStr.contains('Số phiếu') ||
                headersStr.contains('Lần thu') ||
                headersStr.contains('In hóa đơn')) &&
            (headersStr.contains('Đợt thu') ||
                headersStr.contains('Ngày thu') ||
                headersStr.contains('Số tiền'))) {
          paymentReceiptsTable = table;
          debugPrint(
              '💰 [Finance] Identified Payment Receipts Table by signature (${table.length} rows)');
        } else if (feeDetailsTable == null &&
            (headersStr.contains('Loại thu') ||
                headersStr.contains('Số tiền nộp')) &&
            (headersStr.contains('Đã nộp') ||
                headersStr.contains('Số tiền miễn giảm'))) {
          feeDetailsTable = table;
          debugPrint(
              '💰 [Finance] Identified Fee Details Table by signature (${table.length} rows)');
        }
      }

      // Positional index fallback only if signature matching yields null
      tongQuanTable ??= (allTables.isNotEmpty ? allTables[0] : null);
      paymentReceiptsTable ??= (allTables.length >= 2 ? allTables[1] : null);
      feeDetailsTable ??= (allTables.length >= 3 ? allTables[2] : null);

      if (tongQuanTable != null && tongQuanTable.isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving Summary Table (${tongQuanTable.length} rows)');
        await _saveTongQuan(tongQuanTable);
      }
      if (paymentReceiptsTable != null && paymentReceiptsTable.isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving PaymentReceipts Table (${paymentReceiptsTable.length} rows)');
        await _savePaymentReceipts(paymentReceiptsTable);
      }
      if (feeDetailsTable != null && feeDetailsTable.isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving FeeDetails Table (${feeDetailsTable.length} rows)');
        await _saveFeeDetails(feeDetailsTable);
      }

      await DatabaseService.updateCacheMeta(
          'hoc_phi_all',
          HauApiService.hash(
              r.body.substring(0, r.body.length.clamp(0, 2000))));
      debugPrint('💰 [Finance] Done saving');
    } catch (e) {
      debugPrint('💰 [Finance] Error: $e');
    }
  }

  static bool _hasAny(List<String> keys, List<String> targets) =>
      targets.any((t) => keys.any((k) => k.contains(t)));

  // ── SAVE TongQuan → fee_summary ──────────────────────────
  static Future<void> _saveTongQuan(List<Map<String, String>> rows) async {
    for (final row in rows) {
      String col(List<String> keys, String fb) {
        for (final k in keys) {
          final v = row[k];
          if (v != null && v.isNotEmpty) return v;
        }
        return fb;
      }

      // Table[0]: [Học kỳ(_col0), Năm học(_col1), Mực học phí(_col2), Miễn giảm(_col3),
      //            Số tiền phải nộp(_col4), Số tiền đã nộp(_col5), Thừa thiếu(_col6)]
      final hocKy = int.tryParse(col(['Học kỳ', '_col0'], '0')) ?? 0;
      final namHoc = col(['Năm học', '_col1'], '');
      if (namHoc.isEmpty || hocKy == 0) continue;

      await FinanceDb.saveFeeSummary({
        'nam_hoc': namHoc,
        'hoc_ky': hocKy,
        'muc_hoc_phi':
            _parseMoney(col(['Mực học phí', 'Mức học phí', '_col2'], '0')),
        'mien_giam': _parseMoney(col(['Miễn giảm', '_col3'], '0')),
        'phai_nop': _parseMoney(col(['Số tiền phải nộp', '_col4'], '0')),
        'da_nop': _parseMoney(col(['Số tiền đã nộp', '_col5'], '0')),
        'thua_thieu':
            _parseMoney(col(['Thừa thiếu', 'Thừa / thiếu', '_col6'], '0')),
      });
    }
  }

  // ── SAVE ChiTietDaNop → payment_receipts ─────────────────
  // Table[1]: [Năm học(_col0), Học kỳ(_col1), Lần thu(_col2), Đợt thu(_col3),
  //            Ngày thu(_col4), Số phiếu(_col5), Số tiền(_col6), In hóa đơn(_col7)]
  static Future<void> _savePaymentReceipts(
      List<Map<String, String>> rows) async {
    final receipts = <Map<String, dynamic>>[];
    for (final row in rows) {
      String col(List<String> keys, String fb) {
        for (final k in keys) {
          final v = row[k];
          if (v != null && v.isNotEmpty) return v;
        }
        return fb;
      }

      final soPhieu = col(['Số phiếu', '_col5'], '');
      if (soPhieu.isEmpty || soPhieu == 'In hóa đơn') continue;
      if (int.tryParse(soPhieu) == null) continue;

      receipts.add({
        'so_phieu': soPhieu,
        'nam_hoc': col(['Năm học', '_col0'], ''),
        'hoc_ky': int.tryParse(col(['Học kỳ', '_col1'], '1')) ?? 1,
        'lan_thu': int.tryParse(col(['Lần thu', '_col2'], '1')) ?? 1,
        'dot_thu': int.tryParse(col(['Đợt thu', '_col3'], '1')) ?? 1,
        'ngay_thu': col(['Ngày thu', '_col4'], ''),
        'tong_tien_phieu': _parseMoney(col(['Số tiền', '_col6'], '0')),
        'trang_thai': 'Đã nộp',
        'last_updated': DateTime.now().toIso8601String(),
      });
    }
    if (receipts.isNotEmpty) {
      await FinanceDb.savePaymentReceipts(receipts);
    }
  }

  // ── SAVE HoaDonDienTu → fee_details ──────────────────────
  // Table[2]: [Năm học(_col0), Học kỳ(_col1), Ngày nộp(_col2), Số phiếu(_col3),
  //            Loại thu(_col4), Số tiền nộp(_col5), Số tiền miễn giảm(_col6),
  //            Số tiền phải nộp(_col7), Số tiền đã nộp(_col8), Thừa/thiếu(_col9), Đã nộp(_col10)]
  static Future<void> _saveFeeDetails(List<Map<String, String>> rows) async {
    final details = <Map<String, dynamic>>[];
    for (final row in rows) {
      String col(List<String> keys, String fb) {
        for (final k in keys) {
          final v = row[k];
          if (v != null && v.isNotEmpty) return v;
        }
        return fb;
      }

      final soPhieu = col(['Số phiếu', '_col3'], '');
      final loaiThu = col(['Loại thu', '_col4'], '');
      if (soPhieu.isEmpty || loaiThu.isEmpty) continue;
      if (int.tryParse(soPhieu) == null) continue;

      final tenHocPhan =
          loaiThu.contains(':') ? loaiThu.split(':').last.trim() : loaiThu;

      details.add({
        'so_phieu': soPhieu,
        'ten_hoc_phan': tenHocPhan,
        'loai_khoan':
            loaiThu.contains(':') ? loaiThu.split(':').first.trim() : 'Học phí',
        'so_tien_phai_nop':
            _parseMoney(col(['Số tiền phải nộp', '_col7'], '0')),
        'so_tien_mien_giam':
            _parseMoney(col(['Số tiền miễn giảm', '_col6'], '0')),
        'so_tien_da_nop': _parseMoney(col(['Số tiền đã nộp', '_col8'], '0')),
        'so_tien_thua_thieu': _parseMoney(col(['Thừa / thiếu', '_col9'], '0')),
        'trang_thai': col(['Đã nộp', '_col10'], 'Đã nộp'),
        'nam_hoc': col(['Năm học', '_col0'], ''),
        'hoc_ky': int.tryParse(col(['Học kỳ', '_col1'], '1')) ?? 1,
        'ngay_nop': col(['Ngày nộp', '_col2'], ''),
      });
    }
    if (details.isNotEmpty) {
      await FinanceDb.saveFeeDetails(details);
    }
  }
}
