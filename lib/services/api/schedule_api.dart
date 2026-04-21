import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../hau_api_service.dart';
import '../database_service.dart';
import '../mock_data.dart';

class ScheduleApi {
  // ── LỊCH HỌC — single fetch ────────────────────────────

  static Future<List<LichHoc>> fetchLichHoc({
    required int hocKy,
    required int namHoc,
    int chuyenNganh = 0,
    int dotHoc = 1,
  }) async {
    try {
      final url =
          Uri.parse('${HauApiService.base}/TraCuuLichHoc/ThongTinLichHoc')
              .replace(
        queryParameters: {
          'HocKy': '$hocKy',
          'NamHoc': '$namHoc',
          'ChuyenNganh': '$chuyenNganh',
          'Dothoc': '$dotHoc',
        },
      );

      final r = await http
          .get(url, headers: HauApiService.authHeaders)
          .timeout(const Duration(seconds: 15));
      HauApiService.saveCookies(r);

      if (r.statusCode != 200 || r.body.length < 200) return [];

      final doc = HauApiService.parseHtml(r.body);
      final tableRows = doc.querySelectorAll('table tbody tr');
      if (tableRows.length <= 1) return [];

      // ── Parse với rowspan carry-forward ────────────────────
      // Cột API: STT(0) TenHP(1) TC(2) LopTC(3) ThoiGian(4) Thu(5) Tiet(6) Phong(7) GV(8)
      const numCols = 9;
      final carryOver = <int, ({String val, int left})>{};
      final result = <LichHoc>[];

      for (final tr in tableRows) {
        final tds = tr.querySelectorAll('td');
        if (tds.isEmpty) continue;

        // Build row với rowspan
        final cells = List<String>.filled(numCols, '');
        int srcIdx = 0;
        for (int col = 0; col < numCols; col++) {
          if (carryOver.containsKey(col) && carryOver[col]!.left > 0) {
            cells[col] = carryOver[col]!.val;
            final rem = carryOver[col]!.left - 1;
            if (rem == 0)
              carryOver.remove(col);
            else
              carryOver[col] = (val: carryOver[col]!.val, left: rem);
          } else if (srcIdx < tds.length) {
            final td = tds[srcIdx++];
            final val = td.text.trim();
            cells[col] = val;
            final rs = int.tryParse(td.attributes['rowspan'] ?? '1') ?? 1;
            if (rs > 1) carryOver[col] = (val: val, left: rs - 1);
          }
        }

        final tenHoc = cells[1];
        final thoiGian = cells[4];
        final thuRaw = cells[5];
        final tiet = cells[6];

        // Filter: tên môn không được rỗng hoặc chỉ là số
        if (tenHoc.isEmpty) continue;
        if (RegExp(r'^[\d\-]+$').hasMatch(tenHoc)) continue;

        // Thu: số 2-8 → "Thứ N"
        final thuNum = int.tryParse(thuRaw.trim());
        if (thuNum == null || thuNum < 2 || thuNum > 8) continue;
        final thu = 'Thứ $thuNum';

        // Bỏ qua row không có thời gian (dòng trống)
        if (thoiGian.isEmpty) continue;

        result.add(LichHoc(
          tenHocPhan: tenHoc,
          soTinChi: int.tryParse(cells[2]) ?? 0,
          tenLopTinChi: cells[3],
          thoiGian: thoiGian,
          thu: thu,
          tiet: tiet,
          phong: cells[7],
          giaoVien: cells[8],
          hocKy: hocKy,
          namHoc: '$namHoc-${namHoc + 1}',
          dotHoc: dotHoc,
          chuyenNganh: chuyenNganh == 0 ? 'Chính' : 'Thứ 2',
          lastUpdated: DateTime.now(),
        ));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Fetch tất cả đợt × ngành của 1 kỳ song song (giống Python fetchLichHocParallel)
  /// Chỉ lấy năm học 2025-2026 như yêu cầu
  static Future<List<LichHoc>> fetchLichHocAllDots({
    required int hocKy,
    required int namHoc,
    String? mssv, // ← thêm mssv để log
  }) async {
    // 8 đợt × 2 ngành = 16 request chạy song song
    final futures = <Future<List<LichHoc>>>[];
    for (int dot = 1; dot <= 8; dot++) {
      for (int cn = 0; cn <= 1; cn++) {
        futures.add(fetchLichHoc(
          hocKy: hocKy,
          namHoc: namHoc,
          chuyenNganh: cn,
          dotHoc: dot,
        ));
      }
    }

    print('📚 [LichHoc] Bắt đầu fetch: HK$hocKy ${namHoc}-${namHoc + 1} '
        '(16 requests: 8 đợt × 2 ngành)');

    final results = await Future.wait(futures);

    // Log chi tiết từng đợt
    int reqIdx = 0;
    for (int dot = 1; dot <= 8; dot++) {
      for (int cn = 0; cn <= 1; cn++) {
        final list = results[reqIdx++];
        if (list.isNotEmpty) {
          final monNames = list.map((l) => l.tenHocPhan).toSet().join(', ');
          print('   ✅ Đợt $dot | CN${cn == 0 ? "Chính" : "Thứ2"}: '
              '${list.length} bản ghi → $monNames');
        } else {
          print('   ⚪ Đợt $dot | CN${cn == 0 ? "Chính" : "Thứ2"}: rỗng');
        }
      }
    }

    final all = results.expand((r) => r).toList();
    // Deduplicate
    final seen = <String>{};
    final unique = all.where((l) {
      final key = '${l.tenHocPhan}_${l.thoiGian}_${l.thu}_${l.tiet}';
      return seen.add(key);
    }).toList();

    print('📚 [LichHoc] HK$hocKy ${namHoc}-${namHoc + 1}: '
        '${all.length} bản ghi thô → ${unique.length} unique');

    return unique;
  }

  static Future<List<LichHoc>> fetchLichHocFromStart({String? mssv}) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      return MockData.getLichHoc();
    }

    final startYear =
        mssv != null ? HauApiService.getNamBatDauFromMssv(mssv) : 2018;
    final now = DateTime.now();
    // Năm học hiện tại (namHoc = năm bắt đầu của năm học)
    final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

    // Fetch TẤT CẢ kỳ từ startYear → currentNamHoc, không skip gì cả
    final kyList = <({int ky, int nam})>[];
    for (int nam = startYear; nam <= currentNamHoc; nam++) {
      kyList.add((ky: 1, nam: nam));
      kyList.add((ky: 2, nam: nam));
    }

    print('🗓️ [LichHoc] mssv=$mssv startYear=$startYear '
        'currentNamHoc=$currentNamHoc tháng=${now.month} '
        '→ ${kyList.length} kỳ cần fetch (không skip)');
    for (final k in kyList) {
      print('   📋 Sẽ fetch lịch: HK${k.ky} ${k.nam}-${k.nam + 1}');
    }

    final allResults = <LichHoc>[];
    final globalSeen = <String>{};

    for (final k in kyList) {
      print('\n📖 Đang fetch HK${k.ky} ${k.nam}-${k.nam + 1}...');
      final kyResults = await fetchLichHocAllDots(
        hocKy: k.ky,
        namHoc: k.nam,
        mssv: mssv,
      );

      int added = 0;
      for (final l in kyResults) {
        final key =
            '${l.tenHocPhan}_${l.namHoc}_${l.hocKy}_${l.thoiGian}_${l.thu}';
        if (globalSeen.add(key)) {
          allResults.add(l);
          added++;
        }
      }
      if (added > 0) {
        print('   → HK${k.ky} ${k.nam}-${k.nam + 1}: thêm $added bản ghi');
      } else {
        print('   → HK${k.ky} ${k.nam}-${k.nam + 1}: rỗng (chưa có lịch)');
      }
    }

    print('\n🏁 [LichHoc] Tổng kết: ${allResults.length} bản ghi unique '
        'từ ${kyList.length} kỳ');
    return allResults;
  }

  /// Fetch lịch học cho năm 2025-2026, cả 2 học kỳ, song song
  /// Giống fetch_lich_hoc_parallel trong Python nhưng chỉ 2025
  static Future<List<LichHoc>> fetchLichHoc2025() async {
    const namHoc = 2025;
    const hocKys = [1, 2];

    // Chạy cả 2 HK song song
    final futures = hocKys.map((hk) => fetchLichHocAllDots(
          hocKy: hk,
          namHoc: namHoc,
        ));

    final results = await Future.wait(futures);
    final all = results.expand((r) => r).toList();

    print('fetchLichHoc2025: ${all.length} môn tổng cộng');
    return all;
  }

  // ── LỊCH THI ──────────────────────────────────────────────

  static Future<List<LichThi>> fetchLichThi({
    required int hocKy,
    required int namHoc,
  }) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      if (hocKy == 2 && namHoc == 2024) return MockData.getLichThi();
      return [];
    }

    try {
      final url =
          Uri.parse('${HauApiService.base}/TraCuuLichThi/ThongTinLichThi')
              .replace(
        queryParameters: {'HocKy': '$hocKy', 'NamHoc': '$namHoc'},
      );

      var r = await http
          .get(url, headers: HauApiService.authHeaders)
          .timeout(const Duration(seconds: 15));
      HauApiService.saveCookies(r);

      if (r.statusCode != 200 || r.body.length < 200) {
        r = await http
            .get(
              Uri.parse('${HauApiService.base}/TraCuuLichThi/Index'),
              headers: HauApiService.authHeaders,
            )
            .timeout(const Duration(seconds: 15));
        HauApiService.saveCookies(r);
      }

      if (r.statusCode != 200) return [];

      final rows = HauApiService.parseTable(r.body);
      // Sau khi parse, thêm log kiểm tra 1 record đầu:
      if (rows.isNotEmpty) {
        final first = rows.first;
        // In tất cả columns để xác định đúng index
        print('🕐 [LichThi] All columns of first row:');
        first.forEach((k, v) {
          if (v.isNotEmpty) print('   $k = "$v"');
        });
      }
      return rows.map((row) {
        String col(List<String> keys, String fb) {
          for (final k in keys) {
            final v = row[k];
            if (v != null && v.isNotEmpty) return v;
          }
          return fb;
        }

        final tenMon =
            col(['Tên học phần', 'Tên môn học', 'Môn học', '_col2'], '');
        final ngayThi = col(['Ngày thi', '_col4'], '');

        // ✅ Giờ thi ở _col6 (không phải _col3_time hay _col4)
        final gioThiRaw = col(['Giờ thi', 'Giờ', '_col6'], '');

        // Debug log để verify
        if (gioThiRaw.isNotEmpty) {
          print('🕐 gioThiRaw="$gioThiRaw" → '
              'start=${LichThi.parseGioBatDau(gioThiRaw)} '
              'end=${LichThi.parseGioKetThuc(gioThiRaw)}');
        }

        return LichThi(
          tenMonHoc: tenMon,
          maMonHoc: col(['Mã học phần', 'Mã môn', '_col1'], ''),
          soTinChi: int.tryParse(col(['Số tín chỉ', '_col3'], '0')) ?? 0,
          ngayThi: ngayThi,
          caThi: col(['Ca thi', 'Buổi', '_col5'], ''),
          gioBatDau: LichThi.parseGioBatDau(gioThiRaw),
          gioKetThuc: LichThi.parseGioKetThuc(gioThiRaw),
          lanThi: int.tryParse(col(['Lần thi', '_col7'], '0')),
          dotThi: int.tryParse(col(['Đợt thi', '_col8'], '0')),
          sooBaoDanh: col(['Số báo danh', '_col9'], ''),
          phong: col(['Phòng thi', 'Phòng', '_col10'], ''),
          hinhThucThi: col(['Hình thức', 'Hình thức thi', '_col11'], ''),
          hoanThi: col(['Hoãn thi', '_col12'], ''),
          hocKy: hocKy,
          namHoc: '$namHoc-${namHoc + 1}',
          lastUpdated: DateTime.now(),
        );
      }).where((l) {
        // FILTER: Course name cannot be empty or just digits
        if (l.tenMonHoc.isEmpty) {
          print('⚠️ WARN: Skipping lich thi with empty tenMonHoc');
          return false;
        }
        if (RegExp(r'^[0-9\-]+$').hasMatch(l.tenMonHoc)) {
          print('⚠️ WARN: Skipping invalid lich thi name: \"${l.tenMonHoc}\"');
          return false;
        }
        // FILTER: ngayThi must be valid date format
        if (l.ngayThi.isEmpty || !RegExp(r'\d+/\d+/\d+').hasMatch(l.ngayThi)) {
          print(
              '⚠️ WARN: Skipping lich thi with invalid date: \"${l.ngayThi}\"');
          return false;
        }
        return true;
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
