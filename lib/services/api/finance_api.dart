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

  /// Parse TẤT CẢ bảng trong HTML, hỗ trợ rowspan (merged cells)
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

      final rows = <Map<String, String>>[];
      final trs = table.querySelectorAll('tbody tr');

      // rowspan carry-forward: map col-index → (value, rowsLeft)
      final carryOver = <int, ({String val, int left})>{};

      for (final tr in trs) {
        final tds = tr.querySelectorAll('td');
        if (tds.isEmpty) continue;

        final row = <String, String>{};
        int srcIdx = 0; // index vào tds (bỏ qua merged)

        for (int col = 0; col < headers.length; col++) {
          if (carryOver.containsKey(col) && carryOver[col]!.left > 0) {
            // Dùng giá trị từ dòng trên (rowspan)
            row[headers[col]] = carryOver[col]!.val;
            row['_col$col'] = carryOver[col]!.val;
            final rem = carryOver[col]!.left - 1;
            if (rem == 0) {
              carryOver.remove(col);
            } else {
              carryOver[col] = (val: carryOver[col]!.val, left: rem);
            }
          } else if (srcIdx < tds.length) {
            final td = tds[srcIdx++];
            final val = td.text.trim();
            final rs = int.tryParse(td.attributes['rowspan'] ?? '1') ?? 1;
            row[headers[col]] = val;
            row['_col$col'] = val;
            if (rs > 1) {
              carryOver[col] = (val: val, left: rs - 1);
            }
          }
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

      final r = await http
          .get(
            Uri.parse('${HauApiService.base}/TraCuuHocPhi/Index'),
            headers: HauApiService.authHeaders,
          )
          .timeout(const Duration(seconds: 20));

      HauApiService.saveCookies(r);
      if (r.statusCode != 200 || r.body.contains('name="Password"')) {
        debugPrint('💰 [Finance] Not logged in: status=${r.statusCode}');
        return;
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

      // Cấu trúc trang học phí HAU luôn có 3 bảng theo thứ tự cố định:
      // index 0 → TổngQuan    (7 cột)
      // index 1 → Phiếu thu   (8 cột - PaymentReceipts)
      // index 2 → Chi tiết    (11 cột - FeeDetails)
      if (allTables.length >= 1 && allTables[0].isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving TổngQuan (${allTables[0].length} rows)');
        await _saveTongQuan(allTables[0]);
      }
      if (allTables.length >= 2 && allTables[1].isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving PaymentReceipts (${allTables[1].length} rows)');
        await _savePaymentReceipts(allTables[1]);
      }
      if (allTables.length >= 3 && allTables[2].isNotEmpty) {
        debugPrint(
            '💰 [Finance] Saving FeeDetails (${allTables[2].length} rows)');
        await _saveFeeDetails(allTables[2]);
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
