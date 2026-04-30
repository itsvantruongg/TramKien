import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/hau_api_service.dart';
import '../services/database_service.dart';
import '../services/api/grade_api.dart';
import '../services/db/grade_db.dart';

class GradeProvider extends ChangeNotifier {
  // ── Constants ────────────────────────────
  static const Duration _ttlDiem = Duration(hours: 6);

  // ── State ────────────────────────────────
  List<DiemMonHoc> _diem = [];
  List<DiemMonHoc> _diemOverview = []; // Điểm lấy từ trang Index (rút gọn)
  DiemSummary? _diemSummary;
  Map<String, DiemSummary> _semesterSummaries = {};
  bool _diemState = false; // loading

  double _gpa = 0.0;
  int _totalCredits = 0;
  Map<String, double> _gpaByKy = {};
  Map<String, List<DiemMonHoc>> _diemByKy = {};
  Map<String, double> _gpaByKyHe4 = {};

  // ── Getters ─────────────────────────────
  List<DiemMonHoc> get diem => _diem;
  List<DiemMonHoc> get diemOverview => _diemOverview;
  DiemSummary? get diemSummary => _diemSummary;
  Map<String, DiemSummary> get semesterSummaries => _semesterSummaries;
  bool get diemLoading => _diemState;

  double get gpa => _gpa;
  double get gpaHe4 => _diemSummary?.tbcTichLuyHe4 ?? 0.0;
  int get totalCredits => _totalCredits;
  Map<String, double> get gpaByKy => _gpaByKy;
  Map<String, List<DiemMonHoc>> get diemByKy => _diemByKy;
  Map<String, double> get gpaByKyHe4 => _gpaByKyHe4;

  String get xepLoaiHocLuc {
    if (_gpa >= 8.5) return 'Xuất sắc';
    if (_gpa >= 7.0) return 'Giỏi';
    if (_gpa >= 5.5) return 'Khá';
    if (_gpa >= 4.0) return 'Trung bình';
    if (_gpa >= 2.0) return 'Yếu';
    return 'Kém';
  }

  // Thêm field lưu mssv
  String? _mssv;

  // Thêm setter để AppProvider set mssv sau khi login
  void setMssv(String? mssv) {
    _mssv = mssv;
  }

  // Xóa toàn bộ data trong bộ nhớ (gọi khi logout)
  void clearData() {
    _diem = [];
    _diemSummary = null;
    _gpa = 0.0;
    _totalCredits = 0;
    _gpaByKy = {};
    _diemByKy = {};
    _gpaByKyHe4 = {};
    _diemOverview = [];
    _mssv = null;
    notifyListeners();
  }

  // ── Methods ─────────────────────────────

  Future<void> syncDiem({bool forceRefresh = false}) async {
    _diemState = true;
    notifyListeners();
    try {
      final isCached = !forceRefresh &&
          !(await DatabaseService.isStale('diem_all', _ttlDiem));
      if (isCached) {
        await refreshFromCache();
        return;
      }

      final result = await GradeApi.fetchDiemAllKyWithSummary(mssv: _mssv);
      if (result.diem.isNotEmpty) {
        final rawList = result.diem.map((d) => d.toMap()).toList();
        await GradeDb.saveDiem(rawList, mssv: _mssv);
      }

      // SAU: xóa cache overview cũ trước khi lưu mới, đảm bảo mssv đúng
      // Thay đoạn lưu diemOverview cũ bằng:
      if (result.diemOverview.isNotEmpty) {
        await GradeDb.clearOverview(_mssv ?? '');
        await GradeDb.saveDiem(
          result.diemOverview.map((e) {
            final map = e.toMap();
            map['is_overview'] = 1;
            map['mssv'] = _mssv ?? '';
            map['nam_hoc'] = 'Overview';
            map['hoc_ky'] = 0;
            map['attempt'] = 1;
            // Giữ nguyên canVote và status từ data thực tế
            return map;
          }).toList(),
        );
      }

      if (result.complete) {
        await DatabaseService.updateCacheMeta('diem_all', 'synced');
      }

      // ── Load lại từ DB để đảm bảo data nhất quán ──
      _diem = await GradeDb.getDiem();
      _diemOverview = await GradeDb.getDiem(isOverview: true);

      _diemSummary = result.latestSummary ?? await GradeDb.loadDiemSummary();
      if (result.latestSummary != null) {
        await GradeDb.saveDiemSummary(result.latestSummary!);
      }

      // Ưu tiên lấy GPA và Tổng tín chỉ từ API summary (không cần tính toán)
      _gpa = _diemSummary?.tbcTichLuyHe10 ?? 0.0;
      _totalCredits = _diemSummary?.soTinChiTichLuy ?? 0;

      _gpaByKy = await GradeDb.getGPAByKy();
      _gpaByKyHe4 = await GradeDb.getGPAByKyHe4();

      // ← BUILD _diemByKy (bị thiếu hoàn toàn!)
      _diemByKy = {};
      for (final d in _diem) {
        final key = '${d.namHoc}_HK${d.hocKy}';
        _diemByKy.putIfAbsent(key, () => []).add(d);
      }

      _semesterSummaries = await GradeDb.getSemesterSummaries();

      notifyListeners();
    } finally {
      _diemState = false;
      notifyListeners();
    }
  }

  double _he10ToHe4(double d10) {
    if (d10 >= 9.0) return 4.0;
    if (d10 >= 8.5) return 3.7;
    if (d10 >= 8.0) return 3.5;
    if (d10 >= 7.5) return 3.0;
    if (d10 >= 7.0) return 2.5;
    if (d10 >= 6.5) return 2.0;
    if (d10 >= 6.0) return 1.5;
    if (d10 >= 5.0) return 1.0;
    return 0.0;
  }

  Future<void> _computeGpaByKy() async {
    _gpaByKy = await GradeDb.getGPAByKy();
    notifyListeners();
  }

  Future<bool> voteAndRefreshDiem(
    String tenMonHoc,
    int mucDo,
    dynamic diemId, {
    String nhanXet = '',
    String? maMonHoc,
  }) async {
    try {
      final monList = await HauApiService.fetchMonCanVote();
      if (monList.isEmpty) return false;

      String normalize(String value) =>
          value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

      Map<String, String> parseOption(String text) {
        final raw = text.trim();
        final idx = raw.lastIndexOf(' - ');
        if (idx >= 0) {
          return {
            'ten': raw.substring(0, idx).trim(),
            'ma': raw.substring(idx + 3).trim(),
          };
        }
        return {'ten': raw, 'ma': ''};
      }

      final expectedTen = normalize(tenMonHoc);
      final expectedMa = normalize(maMonHoc ?? '');
      final expectedDisplay = normalize(
        maMonHoc != null && maMonHoc.trim().isNotEmpty
            ? '$tenMonHoc - $maMonHoc'
            : tenMonHoc,
      );

      final parsedOptions = monList.map((m) {
        final parsed = parseOption(m['ten'] ?? '');
        return <String, String>{
          'id': m['id'] ?? '',
          'rawText': m['ten'] ?? '',
          'ten': parsed['ten'] ?? '',
          'ma': parsed['ma'] ?? '',
        };
      }).toList();

      Map<String, String>? matched;

      final exactDisplayMatches = parsedOptions
          .where((o) => normalize(o['rawText'] ?? '') == expectedDisplay)
          .toList();
      if (exactDisplayMatches.length == 1) {
        matched = exactDisplayMatches.first;
      } else if (expectedMa.isNotEmpty) {
        final codeMatches = parsedOptions
            .where((o) => normalize(o['ma'] ?? '') == expectedMa)
            .toList();
        if (codeMatches.length == 1) {
          matched = codeMatches.first;
        } else if (codeMatches.length > 1) {
          final bothMatches = codeMatches
              .where((o) => normalize(o['ten'] ?? '') == expectedTen)
              .toList();
          if (bothMatches.length == 1) {
            matched = bothMatches.first;
          }
        }
      }

      if (matched == null) {
        final nameMatches = parsedOptions
            .where((o) => normalize(o['ten'] ?? '') == expectedTen)
            .toList();
        if (nameMatches.length == 1) {
          matched = nameMatches.first;
        }
      }

      if (matched == null || (matched['id'] ?? '').isEmpty) {
        debugPrint(
          'voteAndRefreshDiem: không xác định được môn cần vote '
          'cho "$tenMonHoc" (${maMonHoc ?? ''})',
        );
        return false;
      }

      final idMonTC = matched['id']!;
      final idLop = await HauApiService.fetchIdLopTC(idMonTC);
      if (idLop == null || idLop.isEmpty) return false;

      final info = await HauApiService.fetchTieuChiInfo(idMonTC, idLop);
      if (info == null) return false;

      final ok = await HauApiService.submitVote(
        idMonTC: idMonTC,
        idLopTC: idLop,
        mucDo: mucDo,
        countMax: info['countMax'] ?? 23,
        parentCount: info['parentCount'] ?? 4,
        nhanXet: nhanXet,
      );
      if (!ok) return false;

      if (diemId is int) await GradeDb.markDaVote(diemId);

      _diem = await GradeDb.getDiem();
      _diemByKy = {};
      for (final d in _diem) {
        final key = '${d.namHoc}_HK${d.hocKy}';
        _diemByKy.putIfAbsent(key, () => []).add(d);
      }
      _gpa = await GradeDb.calculateGPA();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('voteAndRefreshDiem error: $e');
      return false;
    }
  }

  Future<void> refreshFromCache() async {
    _diemState = true;
    notifyListeners();
    try {
      _diem =
          await GradeDb.getDiem(isOverview: false); // ← thêm isOverview: false
      _diemOverview = await GradeDb.getDiem(isOverview: true);
      _diemSummary = await GradeDb.loadDiemSummary();
      _gpa = _diemSummary?.tbcTichLuyHe10 ?? 0.0;
      _totalCredits = _diemSummary?.soTinChiTichLuy ?? 0;
      _semesterSummaries = await GradeDb.getSemesterSummaries();
      _gpaByKyHe4 = await GradeDb.getGPAByKyHe4();

      _diemByKy = {};
      for (final d in _diem) {
        final key = '${d.namHoc}_HK${d.hocKy}';
        _diemByKy.putIfAbsent(key, () => []).add(d);
      }
      _semesterSummaries = await GradeDb.getSemesterSummaries();
    } finally {
      _diemState = false; // ← THÊM DÒNG NÀY
      notifyListeners();
    }
  }

  // ── Initialization ──────────────────────

  Future<void> init() async {
    await refreshFromCache();
    await syncDiem();
  }
}
