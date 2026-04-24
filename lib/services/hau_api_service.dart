import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'mock_data.dart';
import 'api/schedule_api.dart';
import 'api/grade_api.dart';
import 'api/finance_api.dart';

// Re-export API classes for easier access
export 'api/schedule_api.dart';
export 'api/grade_api.dart';
export 'api/finance_api.dart';

class HauApiService {
  static const base = 'https://tinchi.hau.edu.vn';

  static final Map<String, String> _cookies = {};
  static String? _currentMssv;
  static String? get currentMssv => _currentMssv;

  static Map<String, String> get _baseHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                'Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
        'Referer': base,
      };

  static String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  static void _saveCookies(http.Response r) {
    final raw = r.headers['set-cookie'];
    if (raw == null) return;
    for (final part in raw.split(RegExp(r',(?=[^ ])'))) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final name = part.substring(0, eq).trim();
      final rest = part.substring(eq + 1);
      final value = rest.split(';').first.trim();
      if (name.isNotEmpty && value.isNotEmpty) {
        _cookies[name] = value;
      }
    }
  }

  // Expose for api/* classes
  static void saveCookies(http.Response r) => _saveCookies(r);
  static Map<String, String> get authHeaders => _authHeaders;

  static Map<String, String> get _authHeaders => {
        ..._baseHeaders,
        if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
      };

  // ── LOGIN ──────────────────────────────────────────────────

  // Trả về null = thành công, trả về String = thông báo lỗi
  static Future<String?> login(String mssv, String password) async {
    try {
      if (mssv == 'admin' && password == 'admin@123') {
        _currentMssv = mssv;
        return null;
      }

      _cookies.clear();

      final r1 = await http
          .get(Uri.parse('$base/DangNhap/Login'), headers: _baseHeaders)
          .timeout(const Duration(seconds: 15));
      _saveCookies(r1);

      final request =
          http.Request('POST', Uri.parse('$base/DangNhap/CheckLogin'));
      request.headers.addAll({
        ..._baseHeaders,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': base,
        'Referer': '$base/DangNhap/Login',
        'Cache-Control': 'max-age=0',
        'Upgrade-Insecure-Requests': '1',
        if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
      });
      request.bodyFields = {
        'Role': '0',
        'UserName': mssv,
        'Password': password,
      };
      request.followRedirects = false;

      final streamed =
          await request.send().timeout(const Duration(seconds: 15));
      final r2 = await http.Response.fromStream(streamed);
      _saveCookies(r2);

      final location = r2.headers['location'] ?? '';

      // Sai mật khẩu → location chứa ?message=...
      if (location.contains('message=')) {
        // Decode message từ URL để hiển thị đúng tiếng Việt
        final uri = Uri.tryParse(location);
        final message =
            uri?.queryParameters['message'] ?? 'Sai tài khoản hoặc mật khẩu';
        return message;
      }

      // Đúng mật khẩu → location không chứa message, redirect về trang chủ
      _currentMssv = mssv;
      return null; // null = thành công
    } on SocketException {
      return 'Không có kết nối mạng';
    } catch (e) {
      return 'Lỗi: $e';
    }
  }

  static bool get isLoggedIn =>
      (_currentMssv == 'admin') ||
      (_cookies.containsKey('ASP.NET_SessionId') && _currentMssv != null);

  static void logout() {
    _cookies.clear();
    _currentMssv = null;
  }

  // ── SESSION CHECK ──────────────────────────────────────────

  static Future<bool> checkSession() async {
    try {
      if (_currentMssv == 'admin') return true;

      final r = await http
          .get(
            Uri.parse('$base/TrangChu/Home'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      _saveCookies(r);
      return r.statusCode == 200 && !r.body.contains('name="Password"');
    } catch (_) {
      return false;
    }
  }

  // ── HTML TABLE PARSER ──────────────────────────────────────
  // Expose for api/* classes
  static List<Map<String, String>> parseTable(String html) => _parseTable(html);
  static dynamic parseHtml(String html) => html_parser.parse(html);
  static String hash(String s) => _hash(s);

  static List<Map<String, String>> _parseTable(String html) {
    try {
      final doc = html_parser.parse(html);
      final table = doc.querySelector('table');
      if (table == null) return [];

      final headerCells = table.querySelectorAll('th');
      final headers = headerCells.isNotEmpty
          ? headerCells.map((e) => e.text.trim()).toList()
          : table
                  .querySelector('tr')
                  ?.querySelectorAll('td')
                  .map((e) => e.text.trim())
                  .toList() ??
              [];

      if (headers.isEmpty) return [];

      final rows = <Map<String, String>>[];
      final trs = table.querySelectorAll('tbody tr');

      for (final tr in trs) {
        final cells = tr.querySelectorAll('td');
        if (cells.isEmpty) continue;
        final row = <String, String>{};
        for (var i = 0; i < headers.length && i < cells.length; i++) {
          row[headers[i]] = cells[i].text.trim();
        }
        for (var i = 0; i < cells.length; i++) {
          row['_col$i'] = cells[i].text.trim();
        }
        if (row.values.any((v) => v.isNotEmpty)) rows.add(row);
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  static String _hash(String s) => md5.convert(utf8.encode(s)).toString();

  // ── SEED ADMIN MOCK DATA ───────────────────────────────────
  // Nạp toàn bộ dữ liệu mẫu vào DB admin một lần duy nhất (idempotent).
  // An toàn khi gọi nhiều lần — chỉ insert nếu DB admin đang rỗng.
  static Future<void> seedAdminMockData() async {
    if (_currentMssv != 'admin' || !MockData.isEnabled) return;
    final alreadySeeded = await DatabaseService.isAdminSeeded();
    if (alreadySeeded) {
      print('✅ Admin DB đã có data, bỏ qua seed.');
      return;
    }
    print('🌱 Đang seed dữ liệu mẫu vào Admin DB...');

    // 1. Thông tin sinh viên
    await DatabaseService.saveStudent(MockData.student);

    // 2. Lịch học
    await ScheduleDb.saveLichHoc(MockData.getLichHoc());

    // 3. Lịch thi
    await ScheduleDb.saveLichThi(MockData.getLichThi());

    // 4. Điểm
    final diem = MockData.getDiem();
    final rawList = diem
        .map((d) => {
              'tenMonHoc': d.tenMonHoc,
              'maMonHoc': d.maMonHoc,
              'soTinChi': d.soTinChi,
              'componentScore': d.componentScore,
              'examScore': d.examScore,
              'avgGrade': d.avgGrade,
              'diemTongKet': d.diemTongKet,
              'xepLoai': d.xepLoai,
              'hocKy': d.hocKy,
              'namHoc': d.namHoc,
              'canVote': d.canVote,
            })
        .toList();
    await GradeDb.saveDiem(rawList);

    // 5. Học phí
    await MockData.populateFinance();
    // 6. Tổng kết học tập (diem summary)
    await GradeDb.saveDiemSummary(MockData.getDiemSummary());

    print('✅ Seed Admin DB hoàn tất (student + lịch + điểm + học phí).');
  }

  // ── THÔNG TIN SINH VIÊN ────────────────────────────────────

  static Future<Student?> fetchThongTinSinhVien() async {
    try {
      if (_currentMssv == 'admin' && MockData.isEnabled) {
        // Seed toàn bộ data nếu chưa có
        await seedAdminMockData();
        return MockData.student;
      }

      final r = await http
          .get(
            Uri.parse('$base/SinhVien/ThongTinSinhVien'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      _saveCookies(r);
      if (r.statusCode != 200 || r.body.contains('name="Password"')) {
        return null;
      }

      final doc = html_parser.parse(r.body);

      String textById(String id) => doc.getElementById(id)?.text.trim() ?? '';
      String valueById(String id) =>
          doc.getElementById(id)?.attributes['value']?.trim() ?? '';

      String spanAfterLabel(String labelText) {
        for (final span in doc.querySelectorAll('span.NoiDungHoSo')) {
          if (span.text.trim().contains(labelText)) {
            final next = span.nextElementSibling;
            if (next != null) return next.text.trim();
          }
        }
        return '';
      }

      final student = Student(
        mssv: textById('lblMaSinhVien').isNotEmpty
            ? textById('lblMaSinhVien')
            : _currentMssv ?? '',
        hoTen: textById('lblHoTen'),
        ngaySinh: textById('lblNgaySinh'),
        gioiTinh: textById('lblGioiTinh'),
        chuyenNganh: spanAfterLabel('Chuyên ngành'),
        heDaoTao: spanAfterLabel('Hệ đào tạo'),
        nienKhoa: spanAfterLabel('Niên khóa'),
        khoaHoc: spanAfterLabel('Khóa học'),
        cmnd: valueById('CMND'),
        email: valueById('Email'),
        dienThoai: valueById('Dienthoai_canhan'),
        queQuan: valueById('Que_quan'),
        diaChiBaoTin: valueById('Dia_chi_bao_tin'),
        lastUpdated: DateTime.now(),
      );

      await DatabaseService.saveStudent(student);
      await DatabaseService.updateCacheMeta('student', _hash(r.body));
      return student;
    } catch (_) {
      return null;
    }
  }

  // ── VOTE ──────────────────────────────────────────────────

  static Future<List<Map<String, String>>> fetchMonCanVote() async {
    try {
      final r = await http
          .get(
            Uri.parse('$base/KhaoSatDanhGia/KhaoSatChatLuongDay'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      _saveCookies(r);

      final doc = html_parser.parse(r.body);
      return doc
          .querySelectorAll('#cmbMonHocKhaoSat option')
          .where((o) {
            final v = o.attributes['value'] ?? '';
            return v.isNotEmpty && v != '-1';
          })
          .map((o) => {'id': o.attributes['value']!, 'ten': o.text.trim()})
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> fetchIdLopTC(String idMonTC, {int cn = 0}) async {
    try {
      final r = await http
          .post(
            Uri.parse('$base/KhaoSatDanhGia/LoadID_LopTC_By_IDMonTC'),
            headers: {
              ..._authHeaders,
              'Content-Type': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
            },
            body: jsonEncode(
                {'IDMonTC': int.tryParse(idMonTC) ?? 0, 'ChuyenNganh': cn}),
          )
          .timeout(const Duration(seconds: 10));
      _saveCookies(r);
      return r.body.trim().replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, int>?> fetchTieuChiInfo(
      String idMonTC, String idLopTC) async {
    try {
      final r = await http
          .get(
            Uri.parse('$base/KhaoSatDanhGia/LoadTieuChiDanhDia'
                '?IDMonTC=$idMonTC&IDLopTC=$idLopTC&ChuyenNganh=0'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      _saveCookies(r);

      final body = r.body;
      final countMax = int.tryParse(RegExp(r"CountIDMaxDanhGia\s*=\s*'(\d+)'")
                  .firstMatch(body)
                  ?.group(1) ??
              '23') ??
          23;
      final parentCount = int.tryParse(
              RegExp(r"ParentLess0\s*=\s*'(\d+)'").firstMatch(body)?.group(1) ??
                  '4') ??
          4;

      return {'countMax': countMax, 'parentCount': parentCount};
    } catch (_) {
      return null;
    }
  }

  static Future<bool> submitVote({
    required String idMonTC,
    required String idLopTC,
    required int mucDo,
    required int countMax,
    required int parentCount,
    String nhanXet = '',
  }) async {
    try {
      final ids =
          List.generate(countMax - parentCount, (i) => parentCount + 1 + i);
      final ketQua = '0,${ids.map((id) => 'YK_${mucDo}_$id').join(',')}';

      final r = await http
          .post(
            Uri.parse('$base/KhaoSatDanhGia/LuuKetQuaDanhGiaMonHoc'),
            headers: {
              ..._authHeaders,
              'Content-Type': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
            },
            body: jsonEncode({
              'KetQua': ketQua,
              'IDMon': idMonTC,
              'IDLop': idLopTC,
              'NhanXet': nhanXet,
            }),
          )
          .timeout(const Duration(seconds: 10));
      _saveCookies(r);
      return r.body.trim().replaceAll('"', '') == 'True';
    } catch (_) {
      return false;
    }
  }

  // Lấy năm bắt đầu học từ MSSV (2 số đầu)
  /// VD: "2355..." → 2023
  static int getNamBatDauFromMssv(String mssv) {
    if (mssv.length < 2) return DateTime.now().year - 2;
    final prefix = int.tryParse(mssv.substring(0, 2)) ?? 23;
    return 2000 + prefix;
  }

  static Future<bool> voteMonHoc(
      {required String idMonTC, required int mucDo}) async {
    final idLop = await fetchIdLopTC(idMonTC);
    if (idLop == null || idLop.isEmpty) return false;
    final info = await fetchTieuChiInfo(idMonTC, idLop);
    if (info == null) return false;
    return submitVote(
      idMonTC: idMonTC,
      idLopTC: idLop,
      mucDo: mucDo,
      countMax: info['countMax'] ?? 23,
      parentCount: info['parentCount'] ?? 4,
    );
  }

  // ── CHƯƠNG TRÌNH ĐÀO TẠO CHÍNH ──────────────────────────────
  /// Trả về list môn học với keys:
  /// khoi, ky, ma, ten, elearning (0/1), tu_chon (0/1), tin_chi, tong_tiet
  static Future<List<Map<String, String>>> fetchChuyenNganhChinh() async {
    try {
      final r = await http
          .get(
            Uri.parse('$base/SinhVien/ChuyenNganhChinh'),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 20));

      saveCookies(r);
      if (r.statusCode != 200 || r.body.contains('name="Password"')) {
        return [];
      }

      final doc = parseHtml(r.body);
      // Try common table selectors
      final table = doc.querySelector('table.table') ??
          doc.querySelector('.table-bordered') ??
          doc.querySelector('table');
      if (table == null) return [];

      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) return [];

      final result = <Map<String, String>>[];
      String currentKhoi = '';
      String currentKy = '';

      for (int i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.isEmpty) continue;

        final cnt = cells.length;
        int offset = 0;

        // Bảng có tối đa 10 cột:
        // [0]Khối [1]Kỳ [2]Mã [3]Tên [4]EL [5]TC [6]SoTC [7]TongTiet [8]ChiTiet [9]TaiLieu
        // Khi Khối rowspan nhiều dòng → các dòng con sẽ thiếu 1-2 cell đầu
        if (cnt >= 10) {
          currentKhoi = cells[0].text.trim();
          currentKy = cells[1].text.trim();
          offset = 2;
        } else if (cnt == 9) {
          currentKy = cells[0].text.trim();
          offset = 1;
        }
        // cnt <= 8: cùng Khối, cùng Kỳ → offset = 0

        if (cnt - offset < 6) continue; // hàng không đủ dữ liệu

        // Elearning / Tự chọn: check bằng child elements (icon, input...)
        bool hasContent(int idx) {
          if (idx >= cells.length) return false;
          final c = cells[idx];
          return c.text.trim().isNotEmpty || c.children.isNotEmpty;
        }

        final ma = cells[offset].text.trim();
        final ten = cells[offset + 1].text.trim();
        if (ma.isEmpty && ten.isEmpty) continue;

        result.add({
          'khoi': currentKhoi,
          'ky': currentKy,
          'ma': ma,
          'ten': ten,
          'elearning': hasContent(offset + 2) ? '1' : '0',
          'tu_chon': hasContent(offset + 3) ? '1' : '0',
          'tin_chi':
              (offset + 4 < cells.length) ? cells[offset + 4].text.trim() : '',
          'tong_tiet':
              (offset + 5 < cells.length) ? cells[offset + 5].text.trim() : '',
        });
      }

      return result
          .where((m) => m['ten']!.isNotEmpty || m['ma']!.isNotEmpty)
          .toList();
    } catch (e) {
      print('fetchChuyenNganhChinh error: $e');
      return [];
    }
  }
}
