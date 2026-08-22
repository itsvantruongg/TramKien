import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../hau_api_service.dart';
import '../database_service.dart';
import '../mock_data.dart';

typedef LichHocFetchResult = ({List<LichHoc> items, bool success});
typedef LichHocScanResult = ({List<LichHoc> items, bool complete});
typedef LichThiFetchResult = ({List<LichThi> items, bool success});
typedef LichThiScanResult = ({List<LichThi> items, bool complete});

/// Helper class for limiting concurrent network requests (e.g. max 3 requests at once)
class ConcurrencyPool {
  final int maxConcurrent;
  int _activeCount = 0;
  final _queue = <Completer<void>>[];

  ConcurrencyPool(this.maxConcurrent);

  Future<T> run<T>(Future<T> Function() task) async {
    if (_activeCount >= maxConcurrent) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _activeCount++;
    try {
      return await task();
    } finally {
      _activeCount--;
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        next.complete();
      }
    }
  }
}

class ScheduleApi {
  // Global concurrency throttle for schedule endpoints (Size 3)
  static final ConcurrencyPool _pool = ConcurrencyPool(3);

  // ── LỊCH HỌC — single fetch ────────────────────────────

  static Future<LichHocFetchResult> fetchLichHocWithStatus({
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

      var r = await http
          .get(url, headers: HauApiService.authHeaders)
          .timeout(const Duration(seconds: 25));
      HauApiService.saveCookies(r);

      // Check session expiration / login HTML
      if (r.statusCode != 200 ||
          r.body.length < 200 ||
          HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
        if (HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          final reauthed = await HauApiService.reauthenticateIfNeeded();
          if (reauthed) {
            r = await http
                .get(url, headers: HauApiService.authHeaders)
                .timeout(const Duration(seconds: 25));
            HauApiService.saveCookies(r);
          }
        }
        if (r.statusCode != 200 ||
            r.body.length < 200 ||
            HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          return (items: <LichHoc>[], success: false);
        }
      }

      final doc = HauApiService.parseHtml(r.body);
      final tableRows = doc.querySelectorAll('table tbody tr');
      if (tableRows.length <= 1) {
        return (items: <LichHoc>[], success: true);
      }

      // ── Parse với 2D grid allocation (hỗ trợ rowspan & colspan) ──────
      const numCols = 9;
      final grid = HauApiService.parseTableGrid(tableRows);
      final result = <LichHoc>[];

      for (final cells in grid) {
        if (cells.length < numCols) continue;

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
      return (items: result, success: true);
    } catch (_) {
      return (items: <LichHoc>[], success: false);
    }
  }

  static Future<List<LichHoc>> fetchLichHoc({
    required int hocKy,
    required int namHoc,
    int chuyenNganh = 0,
    int dotHoc = 1,
  }) async {
    return (await fetchLichHocWithStatus(
      hocKy: hocKy,
      namHoc: namHoc,
      chuyenNganh: chuyenNganh,
      dotHoc: dotHoc,
    ))
        .items;
  }

  static Future<LichHocScanResult> fetchLichHocAllDotsWithStatus({
    required int hocKy,
    required int namHoc,
    String? mssv,
  }) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      final prefs = await SharedPreferences.getInstance();
      final useSetB = prefs.getBool('debug_demo_set_b') ?? false;
      return (items: useSetB ? MockData.getLichHocSetB() : MockData.getLichHoc(), complete: true);
    }

    // 8 đợt × 2 ngành = 16 request chạy qua ConcurrencyPool(3)
    final futures = <Future<LichHocFetchResult>>[];
    for (int dot = 1; dot <= 8; dot++) {
      for (int cn = 0; cn <= 1; cn++) {
        futures.add(_pool.run(() => _fetchLichHocWithRetry(
          hocKy: hocKy,
          namHoc: namHoc,
          chuyenNganh: cn,
          dotHoc: dot,
        )));
      }
    }

    print('📚 [LichHoc] Bắt đầu fetch: HK$hocKy ${namHoc}-${namHoc + 1} '
        '(16 requests via ConcurrencyPool poolSize=3)');

    final results = await Future.wait(futures);

    // Log chi tiết từng đợt
    int reqIdx = 0;
    bool complete = true;
    for (int dot = 1; dot <= 8; dot++) {
      for (int cn = 0; cn <= 1; cn++) {
        final result = results[reqIdx++];
        if (!result.success) complete = false;

        final list = result.items;
        if (list.isNotEmpty) {
          final monNames = list.map((l) => l.tenHocPhan).toSet().join(', ');
          print('   ✅ Đợt $dot | CN${cn == 0 ? "Chính" : "Thứ2"}: '
              '${list.length} bản ghi → $monNames');
        } else {
          print('   ⚪ Đợt $dot | CN${cn == 0 ? "Chính" : "Thứ2"}: rỗng');
        }
      }
    }

    final all = results.expand((r) => r.items).toList();
    final seen = <String>{};
    final unique = all.where((l) {
      final key = '${l.tenHocPhan}_${l.thoiGian}_${l.thu}_${l.tiet}';
      return seen.add(key);
    }).toList();

    print('📚 [LichHoc] HK$hocKy ${namHoc}-${namHoc + 1}: '
        '${all.length} bản ghi thô → ${unique.length} unique '
        'complete=$complete');

    return (items: unique, complete: complete);
  }

  static Future<List<LichHoc>> fetchLichHocAllDots({
    required int hocKy,
    required int namHoc,
    String? mssv,
  }) async {
    return (await fetchLichHocAllDotsWithStatus(
      hocKy: hocKy,
      namHoc: namHoc,
      mssv: mssv,
    ))
        .items;
  }

  static Future<LichHocFetchResult> _fetchLichHocWithRetry({
    required int hocKy,
    required int namHoc,
    required int chuyenNganh,
    required int dotHoc,
    int maxAttempts = 3,
  }) async {
    LichHocFetchResult last = (items: <LichHoc>[], success: false);
    final random = math.Random();
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      last = await fetchLichHocWithStatus(
        hocKy: hocKy,
        namHoc: namHoc,
        chuyenNganh: chuyenNganh,
        dotHoc: dotHoc,
      );
      if (last.success) return last;
      if (attempt < maxAttempts - 1) {
        final delayMs = (400 * (1 << attempt)) + random.nextInt(250);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return last;
  }

  static Future<LichHocScanResult> fetchLichHocFromStartWithStatus({
    String? mssv,
  }) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      final prefs = await SharedPreferences.getInstance();
      final useSetB = prefs.getBool('debug_demo_set_b') ?? false;
      return (items: useSetB ? MockData.getLichHocSetB() : MockData.getLichHoc(), complete: true);
    }

    final startYear =
        mssv != null ? HauApiService.getNamBatDauFromMssv(mssv) : 2018;
    final now = DateTime.now();
    final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

    final kyList = <({int ky, int nam})>[];
    for (int nam = startYear; nam <= currentNamHoc; nam++) {
      kyList.add((ky: 1, nam: nam));
      kyList.add((ky: 2, nam: nam));
    }

    print('🗓️ [LichHoc] mssv=$mssv startYear=$startYear '
        'currentNamHoc=$currentNamHoc tháng=${now.month} '
        '→ ${kyList.length} kỳ cần fetch (không skip)');

    final allResults = <LichHoc>[];
    final globalSeen = <String>{};
    bool complete = true;

    const batchSize = 2;
    for (int start = 0; start < kyList.length; start += batchSize) {
      final end = (start + batchSize < kyList.length)
          ? start + batchSize
          : kyList.length;
      final batch = kyList.sublist(start, end);
      final results = await Future.wait(batch.map((k) =>
          _fetchLichHocSemesterWithRetry(
              hocKy: k.ky, namHoc: k.nam, mssv: mssv)));

      for (int i = 0; i < batch.length; i++) {
        final k = batch[i];
        final result = results[i];
        final kyLabel = 'HK${k.ky} ${k.nam}-${k.nam + 1}';

        if (!result.complete) {
          complete = false;
          print('   🔴 $kyLabel: lỗi sau retry');
        } else if (result.items.isEmpty) {
          print('   ⚪ $kyLabel: rỗng (chưa có lịch)');
        } else {
          final monNames =
              result.items.map((l) => l.tenHocPhan).toSet().join(', ');
          print('   🟢 $kyLabel: ${result.items.length} bản ghi → $monNames');
        }

        for (final l in result.items) {
          final key =
              '${l.tenHocPhan}_${l.namHoc}_${l.hocKy}_${l.thoiGian}_${l.thu}_${l.tiet}_${l.dotHoc}_${l.chuyenNganh}';
          if (globalSeen.add(key)) allResults.add(l);
        }
      }
    }

    print('\n🏁 [LichHoc] Tổng kết: ${allResults.length} bản ghi unique '
        'từ ${kyList.length} kỳ complete=$complete');
    return (items: allResults, complete: complete);
  }

  static Future<List<LichHoc>> fetchLichHocFromStart({String? mssv}) async {
    return (await fetchLichHocFromStartWithStatus(mssv: mssv)).items;
  }

  static Future<LichHocScanResult> _fetchLichHocSemesterWithRetry({
    required int hocKy,
    required int namHoc,
    String? mssv,
    int maxAttempts = 2,
  }) async {
    LichHocScanResult last = (items: <LichHoc>[], complete: false);
    final random = math.Random();
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      last = await fetchLichHocAllDotsWithStatus(
        hocKy: hocKy,
        namHoc: namHoc,
        mssv: mssv,
      );
      if (last.complete) return last;
      if (attempt < maxAttempts - 1) {
        final delayMs = (400 * (1 << attempt)) + random.nextInt(250);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return last;
  }

  /// Fetch lịch học cho năm 2025-2026, cả 2 học kỳ, song song
  static Future<List<LichHoc>> fetchLichHoc2025() async {
    const namHoc = 2025;
    const hocKys = [1, 2];

    final futures = hocKys.map((hk) => fetchLichHocAllDotsWithStatus(
          hocKy: hk,
          namHoc: namHoc,
        ));

    final results = await Future.wait(futures);
    final all = results.expand((r) => r.items).toList();

    print('fetchLichHoc2025: ${all.length} môn tổng cộng');
    return all;
  }

  // ── LỊCH THI ──────────────────────────────────────────────

  static Future<LichThiFetchResult> fetchLichThiWithStatus({
    required int hocKy,
    required int namHoc,
  }) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      if (hocKy == 2 && namHoc == 2024) {
        return (items: MockData.getLichThi(), success: true);
      }
      return (items: <LichThi>[], success: true);
    }

    try {
      final url =
          Uri.parse('${HauApiService.base}/TraCuuLichThi/ThongTinLichThi')
              .replace(
        queryParameters: {'HocKy': '$hocKy', 'NamHoc': '$namHoc'},
      );

      var r = await http
          .get(url, headers: HauApiService.authHeaders)
          .timeout(const Duration(seconds: 25));
      HauApiService.saveCookies(r);

      if (r.statusCode != 200 ||
          r.body.length < 200 ||
          HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
        if (HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          final reauthed = await HauApiService.reauthenticateIfNeeded();
          if (reauthed) {
            r = await http
                .get(url, headers: HauApiService.authHeaders)
                .timeout(const Duration(seconds: 25));
            HauApiService.saveCookies(r);
          }
        }
        if (r.statusCode != 200 ||
            r.body.length < 200 ||
            HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
          r = await http
              .get(
                Uri.parse('${HauApiService.base}/TraCuuLichThi/Index'),
                headers: HauApiService.authHeaders,
              )
              .timeout(const Duration(seconds: 25));
          HauApiService.saveCookies(r);
        }
      }

      if (r.statusCode != 200 ||
          HauApiService.isLoginPage(r.body, statusCode: r.statusCode)) {
        return (items: <LichThi>[], success: false);
      }

      final rows = HauApiService.parseTable(r.body);
      if (rows.isNotEmpty) {
        final first = rows.first;
        print('🕐 [LichThi] All columns of first row:');
        first.forEach((k, v) {
          if (v.isNotEmpty) print('   $k = "$v"');
        });
      }
      final items = rows.map((row) {
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

        final gioThiRaw = col(['Giờ thi', 'Giờ', '_col6'], '');

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
        if (l.tenMonHoc.isEmpty) return false;
        if (RegExp(r'^[0-9\-]+$').hasMatch(l.tenMonHoc)) return false;
        if (l.ngayThi.isEmpty || !RegExp(r'\d+/\d+/\d+').hasMatch(l.ngayThi)) {
          return false;
        }
        return true;
      }).toList();

      return (items: items, success: true);
    } catch (_) {
      return (items: <LichThi>[], success: false);
    }
  }

  static Future<List<LichThi>> fetchLichThi({
    required int hocKy,
    required int namHoc,
  }) async {
    return (await fetchLichThiWithStatus(hocKy: hocKy, namHoc: namHoc)).items;
  }

  static Future<LichThiScanResult> fetchLichThiFromStartWithStatus({
    String? mssv,
  }) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      final prefs = await SharedPreferences.getInstance();
      final useSetB = prefs.getBool('debug_demo_set_b') ?? false;
      return (items: useSetB ? MockData.getLichThiSetB() : MockData.getLichThi(), complete: true);
    }

    final startYear =
        mssv != null ? HauApiService.getNamBatDauFromMssv(mssv) : 2020;
    final now = DateTime.now();
    final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

    final kyList = <({int ky, int nam})>[];
    for (int nam = startYear; nam <= currentNamHoc; nam++) {
      kyList.add((ky: 1, nam: nam));
      kyList.add((ky: 2, nam: nam));
    }

    print('🗓️ [LichThi] mssv=$mssv startYear=$startYear '
        '→ ${kyList.length} kỳ cần fetch (không skip)');

    final allLichThi = <LichThi>[];
    bool complete = true;

    const batchSize = 4;
    for (int start = 0; start < kyList.length; start += batchSize) {
      final end = (start + batchSize < kyList.length)
          ? start + batchSize
          : kyList.length;
      final batch = kyList.sublist(start, end);
      final results = await Future.wait(batch.map(
          (k) => _pool.run(() => _fetchLichThiSemesterWithRetry(hocKy: k.ky, namHoc: k.nam))));

      for (int i = 0; i < batch.length; i++) {
        final k = batch[i];
        final result = results[i];
        final kyLabel = 'HK${k.ky} ${k.nam}-${k.nam + 1}';

        if (!result.success) {
          complete = false;
          print('   🔴 $kyLabel: lỗi sau retry');
        } else if (result.items.isEmpty) {
          print('   ⚪ $kyLabel: rỗng');
        } else {
          print('   🟢 $kyLabel: ${result.items.length} lịch thi → '
              '${result.items.map((t) => t.tenMonHoc).join(', ')}');
          allLichThi.addAll(result.items);
        }
      }
    }

    print(
        '🏁 [LichThi] Tổng: ${allLichThi.length} lịch thi complete=$complete');
    return (items: allLichThi, complete: complete);
  }

  static Future<List<LichThi>> fetchLichThiFromStart({String? mssv}) async {
    return (await fetchLichThiFromStartWithStatus(mssv: mssv)).items;
  }

  static Future<LichThiFetchResult> _fetchLichThiSemesterWithRetry({
    required int hocKy,
    required int namHoc,
    int maxAttempts = 2,
  }) async {
    LichThiFetchResult last = (items: <LichThi>[], success: false);
    final random = math.Random();
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      last = await fetchLichThiWithStatus(hocKy: hocKy, namHoc: namHoc);
      if (last.success) return last;
      if (attempt < maxAttempts - 1) {
        final delayMs = (400 * (1 << attempt)) + random.nextInt(250);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return last;
  }
}
