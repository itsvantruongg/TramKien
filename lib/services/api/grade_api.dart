import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../hau_api_service.dart';
import '../database_service.dart';
import '../mock_data.dart';

typedef DiemResult = ({List<DiemMonHoc> diem, DiemSummary? summary});

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

        final tongKetStr = col(['TK', 'Tổng kết', 'Điểm TK', '_col6'], '');
        final canVote = tongKetStr.toLowerCase().contains('vote') ||
            tongKetStr.contains('*') ||
            tongKetStr.isEmpty;

        return DiemMonHoc(
          tenMonHoc: col(['Tên học phần', 'Môn học', '_col1'], ''),
          maMonHoc: col(['Mã HP', 'Mã môn', '_col0'], ''),
          soTinChi: int.tryParse(col(['TC', 'Số TC', '_col2'], '0')) ?? 0,
          componentScore:
              (double.tryParse(col(['CC', 'Chuyên cần', '_col3'], '')) ?? 0.0)
                  .toString(),
          examScore:
              (double.tryParse(col(['CK', 'Cuối kỳ', '_col5'], '')) ?? 0.0)
                  .toString(),
          avgGrade: double.tryParse(tongKetStr),
          diemTongKet: double.tryParse(tongKetStr),
          xepLoai: col(['XL', 'Xếp loại', '_col7'], ''),
          hocKy: int.tryParse(col(['HK', '_col8'], '1')) ?? 1,
          namHoc: col(['Năm học', '_col9'], ''),
          canVote: canVote,
          lastUpdated: DateTime.now(),
        );
      }).where((d) {
        if (d.tenMonHoc.isEmpty) return false;
        // Lọc các dòng tổng kết/chú thích
        final name = d.tenMonHoc.toLowerCase();
        if (name.contains('tổng số tín chỉ')) return false;
        if (name.contains('số tín chỉ tích lũy')) return false;
        if (name.contains('điểm trung bình')) return false;
        if (name.startsWith('a:') || name.startsWith('b:')) return false;
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
        final m = RegExp(r':\s*([\d]+[.,][\d]+)')
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
        tbcHocTapHe4: ht4,
        tbcHocTapHe10: ht10,
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
        return (diem: <DiemMonHoc>[], summary: null);
      }

      final summary = _parseDiemSummary(r.body);
      final rows = HauApiService.parseTable(r.body);
      final diem = _mapRowsToDiem(rows, hocKy: hocKy, namHoc: namHoc);
      return (diem: diem, summary: summary);
    } catch (_) {
      return (diem: <DiemMonHoc>[], summary: null);
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
        componentScore: lastPart(compRaw), // lấy lần thi cuối
        examScore: lastPart(examRaw),
        avgGrade: parseLast(tbchpRaw), // "1.4 | 8" → 8.0
        diemTongKet: parseLast(diemSoRaw),
        xepLoai: lastPart(diemChuRaw),
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
    futures.add(fetchDiem().then((d) => (diem: d, summary: null))); // fallback

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
  static Future<({List<DiemMonHoc> diem, DiemSummary? latestSummary})>
      fetchDiemAllKyWithSummary({String? mssv}) async {
    if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
      return (
        diem: MockData.getDiem(),
        latestSummary: MockData.getDiemSummary()
      );
    }

    final startYear =
        mssv != null ? HauApiService.getNamBatDauFromMssv(mssv) : 2018;
    final now = DateTime.now();

    // namHoc = năm BẮT ĐẦU của năm học (2018 → năm học 2018-2019)
    // Năm học hiện tại = tháng >= 8 ? now.year : now.year - 1
    final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

    // Kỳ hiện tại trong năm học đó
    // Tháng 8-1 (học kỳ 1: tháng 8 → tháng 1 năm sau)
    // Tháng 2-7 (học kỳ 2)
    // Kỳ đang học (chưa có điểm) = không tính
    // Logic: tháng 8-12 → đang HK1 → chỉ fetch đến HK2 của năm trước
    //         tháng 1    → đang cuối HK1 → fetch đến HK2 của năm trước
    //         tháng 2-7  → đang HK2 → fetch đến HK1 của năm hiện tại
    //
    // Đơn giản hơn: fetch TẤT CẢ từ startYear → currentNamHoc,
    // kỳ nào API trả rỗng = chưa có điểm, bỏ qua tự nhiên
    // Chỉ SKIP kỳ đang học hiện tại (chắc chắn rỗng, không cần fetch)

    // Xác định kỳ đang học để skip
    final int skipNam;
    final int skipKy;
    if (now.month >= 8) {
      // Đang HK1 của currentNamHoc
      skipNam = currentNamHoc;
      skipKy = 1;
    } else if (now.month >= 2) {
      // Đang HK2 của currentNamHoc
      skipNam = currentNamHoc;
      skipKy = 2;
    } else {
      // Tháng 1: vẫn đang HK1 (thi cuối kỳ), có thể đã có điểm
      // Không skip gì cả
      skipNam = -1;
      skipKy = -1;
    }

    // Build danh sách kỳ: startYear → currentNamHoc, HK1 rồi HK2
    final kyList = <({int ky, int nam})>[];
    for (int nam = startYear; nam <= currentNamHoc; nam++) {
      for (int ky = 1; ky <= 2; ky++) {
        // Skip kỳ đang học (chưa có điểm tổng kết)
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

    // Fetch trang Index để lấy summary TỔNG (tích lũy toàn khóa)
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
        print('📊 Index summary: tbc10=${latestSummary?.tbcTichLuyHe10} '
            'tbc4=${latestSummary?.tbcTichLuyHe4}');
      }
    } catch (e) {
      print('⚠️ Fetch Index summary lỗi: $e');
    }

    // Fetch TUẦN TỰ từng kỳ + retry 1 lần nếu rỗng
    int totalFound = 0;
    for (final k in kyList) {
      DiemResult result;
      try {
        result = await fetchDiemWithSummary(hocKy: k.ky, namHoc: k.nam);

        // Retry 1 lần nếu rỗng (tránh network flaky)
        if (result.diem.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 400));
          result = await fetchDiemWithSummary(hocKy: k.ky, namHoc: k.nam);
        }
      } catch (e) {
        print('❌ Fetch HK${k.ky} ${k.nam}-${k.nam + 1} lỗi: $e');
        result = (diem: <DiemMonHoc>[], summary: null);
      }

      final kyLabel = 'HK${k.ky} ${k.nam}-${k.nam + 1}';
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
    }

    print('🏁 Tổng kết: $totalFound môn (${all.length} unique) '
        'từ ${kyList.length} kỳ đã fetch');
    return (diem: all, latestSummary: latestSummary);
  }
}
