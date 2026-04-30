import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../hau_api_service.dart';
import '../mock_data.dart';
import '../db/grade_db.dart';


typedef DiemResult = ({
  List<DiemMonHoc> diem,
  DiemSummary? summary,
  bool success
});

class GradeApi {
  // ── ĐIỂM ──────────────────────────────────────────────────

  static Future<List<DiemMonHoc>> fetchDiem() async {
    try {
      final r = await http
          .get(
            Uri.parse('${HauApiService.base}/TraCuuDiem/Index'),
            headers: HauApiService.authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      HauApiService.saveCookies(r);
      if (r.statusCode != 200 || r.body.contains('name="Password"')) {
        return [];
      }

      final rows = HauApiService.parseTable(r.body);
      return rows.map((row) {
        String col(List<String> keys, String fb) {
          for (final k in keys) {
            final v = row[k];
            if (v != null && v.isNotEmpty) return v;
          }
          return fb;
        }

        // Lấy giá trị cuối nếu có "|" (cho logic App hiện tại)
        double? parseLast(String raw) {
          if (raw.isEmpty) return null;
          final parts = raw.split('|').map((e) => e.trim()).toList();
          for (final p in parts.reversed) {
            final v = double.tryParse(p);
            if (v != null) return v;
          }
          return null;
        }

        String lastPart(String raw) {
          if (!raw.contains('|')) return raw;
          return raw.split('|').last.trim();
        }

        // Cập nhật mapping theo ảnh mới nhất:
        // _col1: Ký hiệu, _col2: Tên học phần, _col3: Số tín chỉ, _col4: Hệ số,
        // _col5: Điểm thành phần, _col6: Điểm thi, _col7: TBCHP, _col8: Điểm số, _col9: Điểm chữ
        final maHp = col(['Ký hiệu', '_col1'], '');
        final tenHp = col(['Tên học phần', '_col2'], '');
        final soTc = int.tryParse(col(['Số tín chỉ', 'TC', '_col3'], '0')) ?? 0;
        final compRaw = col(['Điểm thành phần', '_col5'], '');
        final examRaw = col(['Điểm thi', '_col6'], '');
        final tbchpRaw = col(['TBCHP', '_col7'], '');
        final diemSoRaw = col(['Điểm số', '_col8'], '');
        final diemChuRaw = col(['Điểm chữ', '_col9'], '');

        final canVote = tbchpRaw.toLowerCase().contains('vote') ||
            diemSoRaw.toLowerCase().contains('vote') ||
            diemChuRaw.toLowerCase().contains('vote') ||
            diemChuRaw.contains('*') ||
            diemChuRaw.isEmpty;

        return DiemMonHoc(
          tenMonHoc: tenHp,
          maMonHoc: maHp,
          soTinChi: soTc,
          componentScore: lastPart(compRaw),
          examScore: lastPart(examRaw),
          avgGrade: parseLast(tbchpRaw),
          diemTongKet: parseLast(diemSoRaw),
          xepLoai: lastPart(diemChuRaw),
          // Lưu dữ liệu gốc để hiển thị "F | B"
          rawAvgGrade: tbchpRaw,
          rawDiemSo: diemSoRaw,
          rawXepLoai: diemChuRaw,
          rawComponentScore: compRaw,
          rawExamScore: examRaw,
          hocKy: 0, // 0 = Overview
          namHoc: 'Overview',
          canVote: canVote,
          lastUpdated: DateTime.now(),
        );
      }).where((d) {
        if (d.tenMonHoc.isEmpty) return false;
        final name = d.tenMonHoc.toLowerCase();
        if (name.contains('tổng số tín chỉ') ||
            name.contains('số tín chỉ tích lũy') ||
            name.contains('điểm trung bình')) return false;
        if (d.soTinChi == 0 && d.maMonHoc.isEmpty) return false;
        return true;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Parse phần tổng hợp phía trên bảng điểm
  static DiemSummary? _parseDiemSummary(String html) {
    try {
      final doc = HauApiService.parseHtml(html);
      final plainText = doc.body?.text ?? '';

      // Helper: lấy giá trị số ngay sau label trong plain text
      double? findDouble(String label) {
        final idx = plainText.indexOf(label);
        if (idx < 0) return null;
        final sub = plainText.substring(idx + label.length);
        // Bỏ qua dấu ":" và khoảng trắng, lấy số đầu tiên
        final m = RegExp(r':\s*(\d+(?:[.,]\d+)?)')
            .firstMatch(sub.substring(0, sub.length.clamp(0, 50)));
        return m != null
            ? double.tryParse(m.group(1)!.replaceAll(',', '.'))
            : null;
      }

      int? findInt(String label) {
        final idx = plainText.indexOf(label);
        if (idx < 0) return null;
        final sub = plainText.substring(idx + label.length,
            (idx + label.length + 50).clamp(0, plainText.length));
        final m = RegExp(r':\s*(\d+)').firstMatch(sub);
        return m != null ? int.tryParse(m.group(1)!) : null;
      }

      // TC tích lũy dạng ": 79 / 79"
      int? tcA, tcB;
      final idx = plainText.indexOf('Số tín chỉ tích lũy');
      if (idx >= 0) {
        final sub =
            plainText.substring(idx, (idx + 60).clamp(0, plainText.length));
        final m = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(sub);
        if (m != null) {
          tcA = int.tryParse(m.group(1)!);
          tcB = int.tryParse(m.group(2)!);
        }
      }

      // Xếp loại: lấy text sau ":" không phải số, không phải rỗng
      String findXepLoai(String label) {
        final idx = plainText.indexOf(label);
        if (idx < 0) return '';
        final sub = plainText.substring(idx + label.length,
            (idx + label.length + 80).clamp(0, plainText.length));
        final m =
            RegExp(r':\s*([A-Za-zÀ-ỹ][A-Za-zÀ-ỹ\s]{1,30})').firstMatch(sub);
        return m?.group(1)?.trim() ?? '';
      }

      final tbc4 = findDouble('TBC tích lũy (Hệ 4)');
      final tbc10 = findDouble('TBC tích lũy (Hệ 10)');
      final ht4 = findDouble('TBC học tập (Hệ 4)');
      final ht10 = findDouble('TBC học tập (Hệ 10)');
      final xl4 = findXepLoai('Xếp loại học tập (Hệ 4)');
      final xl10 = findXepLoai('Xếp loại học tập (Hệ 10)');
      final tcHt = findInt('Số tín chỉ học tập');
      final kt = findDouble('Điểm khen thưởng');

      print('✅ parseDiemSummary: tbc4=$tbc4 tbc10=$tbc10 '
          'ht4=$ht4 ht10=$ht10 xl4=$xl4 xl10=$xl10 '
          'tc=$tcA/$tcB tcHt=$tcHt kt=$kt');

      if (tbc4 == null && tbc10 == null) return null;

      return DiemSummary(
        tbcTichLuyHe4: tbc4,
        tbcTichLuyHe10: tbc10,
        tbcHocTapHe4: ht4 ?? tbc4,
        tbcHocTapHe10: ht10 ?? tbc10,
        xepLoaiHe4: xl4,
        xepLoaiHe10: xl10,
        soTinChiTichLuy: tcA,
        soTinChiTichLuyMax: tcB,
        soTinChiHocTap: tcHt,
        diemKhenThuong: kt,
      );
    } catch (e) {
      print('❌ _parseDiemSummary error: $e');
      return null;
    }
  }

  static Future<DiemResult> fetchDiemWithSummary({
    required int hocKy,
    required int namHoc,
    int chuyenNganh = 0,
  }) async {
    try {
      final url =
          Uri.parse('${HauApiService.base}/TraCuuDiem/ThongTinDiemSinhVien')
              .replace(
        queryParameters: {
          'HocKy': '$hocKy',
          'NamHoc': '$namHoc',
          'ChuyenNganh': '$chuyenNganh',
        },
      );

      final r = await http.get(url, headers: {
        ...HauApiService.authHeaders,
        'Accept': 'text/html, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${HauApiService.base}/TraCuuDiem/Index',
      }).timeout(const Duration(seconds: 20));

      HauApiService.saveCookies(r);
      if (r.statusCode != 200 || r.body.length < 200) {
        return (diem: <DiemMonHoc>[], summary: null, success: false);
      }

      final summary = _parseDiemSummary(r.body);
      final rows = HauApiService.parseTable(r.body);
      final diem = _mapRowsToDiem(rows, hocKy: hocKy, namHoc: namHoc);
      return (diem: diem, summary: summary, success: true);
    } catch (_) {
      return (diem: <DiemMonHoc>[], summary: null, success: false);
    }
  }

  // Helper dùng chung
  static List<DiemMonHoc> _mapRowsToDiem(
    List<Map<String, String>> rows, {
    required int hocKy,
    required int namHoc,
  }) {
    return rows.map((row) {
      String col(List<String> keys, String fb) {
        for (final k in keys) {
          final v = row[k];
          if (v != null && v.isNotEmpty) return v;
        }
        return fb;
      }

      // Lấy giá trị cuối cùng nếu có dạng "x | y" (thi lại lấy lần cuối)
      double? parseLast(String raw) {
        if (raw.isEmpty) return null;
        final parts = raw.split('|').map((e) => e.trim()).toList();
        for (final p in parts.reversed) {
          final v = double.tryParse(p);
          if (v != null) return v;
        }
        return null;
      }

      String lastPart(String raw) {
        if (!raw.contains('|')) return raw;
        return raw.split('|').last.trim();
      }

      final tbchpRaw = col(['TBCHP', '_col7'], '');
      final diemSoRaw = col(['Điểm số', '_col8'], '');
      final diemChuRaw = col(['Điểm chữ', '_col9'], '');
      final compRaw = col(['Điểm thành phần', '_col5'], '');
      final examRaw = col(['Điểm thi', '_col6'], '');

      final canVote = tbchpRaw.toLowerCase().contains('vote') ||
          diemSoRaw.toLowerCase().contains('vote') ||
          diemChuRaw.toLowerCase().contains('vote');

      return DiemMonHoc(
        tenMonHoc: col(['Tên học phần', '_col2'], ''),
        maMonHoc: col(['Ký hiệu', '_col1'], ''),
        soTinChi: int.tryParse(col(['Số tín chỉ', '_col3'], '0')) ?? 0,
        componentScore: lastPart(compRaw),
        examScore: lastPart(examRaw),
        avgGrade: parseLast(tbchpRaw),
        diemTongKet: parseLast(diemSoRaw),
        xepLoai: lastPart(diemChuRaw),
        rawAvgGrade: tbchpRaw,
        rawDiemSo: diemSoRaw,
        rawXepLoai: diemChuRaw,
        rawComponentScore: compRaw,
        rawExamScore: examRaw,
        hocKy: hocKy,
        namHoc: '$namHoc-${namHoc + 1}',
        canVote: canVote,
        lastUpdated: DateTime.now(),
      );
    }).where((d) {
      if (d.tenMonHoc.isEmpty) return false;
      final name = d.tenMonHoc.toLowerCase();
      if (name.contains('tổng số tín chỉ')) return false;
      if (name.contains('số tín chỉ tích lũy')) return false;
      if (name.contains('điểm trung bình')) return false;
      if (name.startsWith('a:') || name.startsWith('b:')) return false;
      if (name == 'stt' || d.tenMonHoc == 'Tên học phần') return false;
      return true;
    }).toList();
  }

  static Future<DiemResult> _fetchDiemSemesterWithRetry({
    required int hocKy,
    required int namHoc,
    int maxAttempts = 2,
  }) async {
    DiemResult last = (diem: <DiemMonHoc>[], summary: null, success: false);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      last = await fetchDiemWithSummary(hocKy: hocKy, namHoc: namHoc);
      if (last.success) return last;
      if (attempt < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return last;
  }

  /// Fetch TẤT CẢ điểm không giới hạn năm (dùng cho admin/debug)
  static Future<List<DiemMonHoc>> fetchDiemAllKyFull({
    int startYear = 2018,
  }) async {
    final currentYear = DateTime.now().year;
    final futures = <Future<DiemResult>>[];
    for (int nam = startYear; nam <= currentYear; nam++) {
      for (int ky = 1; ky <= 2; ky++) {
        futures.add(fetchDiemWithSummary(hocKy: ky, namHoc: nam));
      }
    }
    futures.add(fetchDiem()
        .then((d) => (diem: d, summary: null, success: true))); // fallback

    final results = await Future.wait(futures);
    final seen = <String>{};
    final all = <DiemMonHoc>[];
    for (final r in results) {
      for (final d in r.diem) {
        final key = '${d.tenMonHoc}_${d.namHoc}_${d.hocKy}';
        if (seen.add(key)) all.add(d);
      }
    }
    return all;
  }

  /// Fetch điểm theo kỳ dựa vào MSSV (chỉ từ năm nhập học → hiện tại)
  ///
  /// Luồng sync:
  /// 1) Fetch lần 1 theo từng kỳ
  /// 2) Chỉ những kỳ bị lỗi mới được đưa vào danh sách retry
  /// 3) Retry riêng các kỳ thiếu ở lần 2
  /// 4) Chỉ trả complete=true khi không còn kỳ nào lỗi sau retry
  static Future<
      ({
        List<DiemMonHoc> diem,
        List<DiemMonHoc> diemOverview,
        DiemSummary? latestSummary,
        bool complete
      })> fetchDiemAllKyWithSummary({String? mssv}) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      return (
        diem: MockData.getDiem(),
        diemOverview: MockData.getDiemOverview(),
        latestSummary: MockData.getDiemSummary(),
        complete: true,
      );
    }

    final startYear =
        mssv != null ? HauApiService.getNamBatDauFromMssv(mssv) : 2018;
    final now = DateTime.now();

    // namHoc = năm BẮT ĐẦU của năm học (2018 → năm học 2018-2019)
    // Năm học hiện tại = tháng >= 8 ? now.year : now.year - 1
    final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

    // Kỳ đang học (chưa có điểm) = không tính
    // Logic:
    // - tháng 8-12 → đang HK1 → skip HK1 của năm hiện tại
    // - tháng 2-7  → đang HK2 → skip HK2 của năm hiện tại
    // - tháng 1    → vẫn có thể đang chốt điểm HK1 → không skip gì cả

    // Fetch toàn bộ kỳ, không bỏ qua kỳ nào của năm hiện tại
    const int skipNam = -1;
    const int skipKy = -1;

    final kyList = <({int ky, int nam})>[];
    for (int nam = startYear; nam <= currentNamHoc; nam++) {
      for (int ky = 1; ky <= 2; ky++) {
        if (nam == skipNam && ky == skipKy) continue;
        kyList.add((ky: ky, nam: nam));
      }
    }

    print('🗓️ fetchDiem: mssv=$mssv startYear=$startYear '
        'currentNamHoc=$currentNamHoc tháng=${now.month} '
        'skip=HK${skipKy}_${skipNam} → ${kyList.length} kỳ cần fetch');
    for (final k in kyList) {
      print('   📋 Sẽ fetch: HK${k.ky} ${k.nam}-${k.nam + 1}');
    }

    final seen = <String>{};
    final all = <DiemMonHoc>[];
    DiemSummary? latestSummary;
    bool complete = true;
    final pendingKyList = <({int ky, int nam})>[];
    final unresolvedKyList = <({int ky, int nam})>[];
    List<DiemMonHoc> diemOverview = [];

    // Fetch trang Index để lấy summary TỔNG (tích lũy toàn khóa) và danh sách điểm Overview
    // Trong fetchDiemAllKyWithSummary, thay đoạn fetch Index:

// Fetch trang Index để lấy summary TỔNG
    try {
      final indexResp = await http
          .get(
            Uri.parse('${HauApiService.base}/TraCuuDiem/Index'),
            headers: HauApiService.authHeaders,
          )
          .timeout(const Duration(seconds: 20));
      HauApiService.saveCookies(indexResp);
      if (indexResp.statusCode == 200 &&
          !indexResp.body.contains('name="Password"')) {
        latestSummary = _parseDiemSummary(indexResp.body);
        print('📊 Index summary: tbc10=${latestSummary?.tbcTichLuyHe10}');
      }
    } catch (e) {
      print('⚠️ Fetch Index summary lỗi: $e');
    }

// Fetch overview riêng bằng ThongTinDiemSinhVien không tham số
    try {
      final overviewUrl =
          Uri.parse('${HauApiService.base}/TraCuuDiem/ThongTinDiemSinhVien')
              .replace(queryParameters: {
        'HocKy': '0',
        'NamHoc': '0',
        'ChuyenNganh': '0',
      });

      final overviewResp = await http.get(overviewUrl, headers: {
        ...HauApiService.authHeaders,
        'Accept': 'text/html, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${HauApiService.base}/TraCuuDiem/Index',
      }).timeout(const Duration(seconds: 20));

      HauApiService.saveCookies(overviewResp);

      if (overviewResp.statusCode == 200 &&
          overviewResp.body.length > 200 &&
          !overviewResp.body.contains('name="Password"')) {
        // Cập nhật summary từ overview nếu chưa có
        final overviewSummary = _parseDiemSummary(overviewResp.body);
        latestSummary ??= overviewSummary;

        final rows = HauApiService.parseTable(overviewResp.body);
        print('📋 [Overview] parseTable → ${rows.length} dòng thô');

        diemOverview = rows.map((row) {
          String col(List<String> keys, String fb) {
            for (final k in keys) {
              final v = row[k];
              if (v != null && v.isNotEmpty) return v;
            }
            return fb;
          }

          double? parseLast(String raw) {
            if (raw.isEmpty) return null;
            final parts = raw.split('|').map((e) => e.trim()).toList();
            for (final p in parts.reversed) {
              final v = double.tryParse(p);
              if (v != null) return v;
            }
            return null;
          }

          String lastPart(String raw) {
            if (!raw.contains('|')) return raw;
            return raw.split('|').last.trim();
          }

          final maHp = col(['Ký hiệu', '_col1'], '');
          final tenHp = col(['Tên học phần', '_col2'], '');
          final soTc =
              int.tryParse(col(['Số tín chỉ', 'TC', '_col3'], '0')) ?? 0;
          final compRaw = col(['Điểm thành phần', '_col5'], '');
          final examRaw = col(['Điểm thi', '_col6'], '');
          final tbchpRaw = col(['TBCHP', '_col7'], '');
          final diemSoRaw = col(['Điểm số', '_col8'], '');
          final diemChuRaw = col(['Điểm chữ', '_col9'], '');

          return DiemMonHoc(
            tenMonHoc: tenHp,
            maMonHoc: maHp,
            soTinChi: soTc,
            componentScore: lastPart(compRaw),
            examScore: lastPart(examRaw),
            avgGrade: parseLast(tbchpRaw),
            diemTongKet: parseLast(diemSoRaw),
            xepLoai: lastPart(diemChuRaw),
            rawAvgGrade: tbchpRaw,
            rawDiemSo: diemSoRaw,
            rawXepLoai: diemChuRaw,
            rawComponentScore: compRaw,
            rawExamScore: examRaw,
            hocKy: 0,
            namHoc: 'Overview',
            canVote: tbchpRaw.toLowerCase().contains('vote') ||
                diemSoRaw.toLowerCase().contains('vote') ||
                diemChuRaw.toLowerCase().contains('vote') ||
                examRaw.toLowerCase().contains('vote'),
            lastUpdated: DateTime.now(),
          );
        }).where((d) {
          if (d.tenMonHoc.isEmpty) return false;
          if (d.soTinChi == 0) return false;
          final name = d.tenMonHoc.toLowerCase();
          if (name.contains('tổng') || name.contains('trung bình'))
            return false;
          return true;
        }).toList();

        print('📊 Overview: ${diemOverview.length} môn');
        if (diemOverview.isNotEmpty) {
          print(
              '📋 [Overview] Các môn: ${diemOverview.map((d) => d.tenMonHoc).join(', ')}');
        }
      }
    } catch (e) {
      print('⚠️ Fetch Overview riêng lỗi: $e');
    }

    const batchSize = 3;
    int totalFound = 0;

    // Pass 1: chỉ fetch từng kỳ một lần
    for (int start = 0; start < kyList.length; start += batchSize) {
      final end = (start + batchSize < kyList.length)
          ? start + batchSize
          : kyList.length;
      final batch = kyList.sublist(start, end);
      final results = await Future.wait(
        batch.map((k) => fetchDiemWithSummary(hocKy: k.ky, namHoc: k.nam)),
      );

      for (int i = 0; i < batch.length; i++) {
        final k = batch[i];
        final result = results[i];
        final kyLabel = 'HK${k.ky} ${k.nam}-${k.nam + 1}';

        if (!result.success) {
          pendingKyList.add(k);
          complete = false;
          print('   🟠 $kyLabel: lỗi lần 1, sẽ retry riêng');
          continue;
        }

        if (result.diem.isEmpty) {
          print('   ⚪ $kyLabel: rỗng (chưa có điểm hoặc chưa học)');
        } else {
          final monNames = result.diem.map((d) => d.tenMonHoc).join(', ');
          print('   🟢 $kyLabel: ${result.diem.length} môn → $monNames');
          totalFound += result.diem.length;
        }

        for (final d in result.diem) {
          final key = '${d.tenMonHoc}_${d.namHoc}_${d.hocKy}';
          if (seen.add(key)) all.add(d);
        }

        // Lấy summary từ kỳ mới nhất có data (fallback nếu Index không có)
        if (latestSummary == null &&
            result.summary != null &&
            (result.summary!.tbcTichLuyHe4 != null ||
                result.summary!.tbcTichLuyHe10 != null)) {
          latestSummary = result.summary;
        }
        // Lưu summary học kỳ vào DB
        if (result.summary != null) {
          await GradeDb.saveSemesterSummary(
            mssv: mssv ?? '',
            namHoc: '${k.nam}-${k.nam + 1}',
            hocKy: k.ky,
            tbc10: result.summary!.tbcHocTapHe10,
            tbc4: result.summary!.tbcHocTapHe4,
            tc: result.summary!.soTinChiHocTap,
          );
        }
      }
    }

    // Pass 2: chỉ retry các kỳ bị lỗi ở pass 1
    if (pendingKyList.isNotEmpty) {
      print('🔁 Retry riêng ${pendingKyList.length} kỳ bị thiếu...');
      const retryBatchSize = 2;
      for (int start = 0;
          start < pendingKyList.length;
          start += retryBatchSize) {
        final end = (start + retryBatchSize < pendingKyList.length)
            ? start + retryBatchSize
            : pendingKyList.length;
        final retryBatch = pendingKyList.sublist(start, end);
        final retryResults = await Future.wait(retryBatch.map(
            (k) => _fetchDiemSemesterWithRetry(hocKy: k.ky, namHoc: k.nam)));

        for (int i = 0; i < retryBatch.length; i++) {
          final k = retryBatch[i];
          final retry = retryResults[i];
          final kyLabel = 'HK${k.ky} ${k.nam}-${k.nam + 1}';

          if (!retry.success) {
            unresolvedKyList.add(k);
            print('   🔴 $kyLabel: vẫn lỗi sau retry');
            continue;
          }

          if (retry.diem.isEmpty) {
            print('   ⚪ $kyLabel: retry trả rỗng');
          } else {
            final monNames = retry.diem.map((d) => d.tenMonHoc).join(', ');
            print('   🟢 $kyLabel: retry ${retry.diem.length} môn → $monNames');
            totalFound += retry.diem.length;
          }

          for (final d in retry.diem) {
            final key = '${d.tenMonHoc}_${d.namHoc}_${d.hocKy}';
            if (seen.add(key)) all.add(d);
          }

          if (latestSummary == null &&
              retry.summary != null &&
              (retry.summary!.tbcTichLuyHe4 != null ||
                  retry.summary!.tbcTichLuyHe10 != null)) {
            latestSummary = retry.summary;
          }
          if (retry.summary != null) {
            await GradeDb.saveSemesterSummary(
              mssv: mssv ?? '',
              namHoc: '${k.nam}-${k.nam + 1}',
              hocKy: k.ky,
              tbc10: retry.summary!.tbcHocTapHe10,
              tbc4: retry.summary!.tbcHocTapHe4,
              tc: retry.summary!.soTinChiHocTap,
            );
          }
        }
      }
    }

    final unresolvedCount = unresolvedKyList.length;
    complete = complete && unresolvedCount == 0;

    print('🏁 Tổng kết: $totalFound môn (${all.length} unique) '
        'từ ${kyList.length} kỳ đã fetch complete=$complete '
        'pending=${pendingKyList.length} unresolved=$unresolvedCount');
    return (
      diem: all,
      diemOverview: diemOverview,
      latestSummary: latestSummary,
      complete: complete
    );
  }
}
