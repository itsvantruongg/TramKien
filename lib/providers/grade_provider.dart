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
  DiemSummary? _diemSummary;
  bool _diemState = false; // loading

  double _gpa = 0.0;
  int _totalCredits = 0;
  Map<String, double> _gpaByKy = {};
  Map<String, List<DiemMonHoc>> _diemByKy = {};
  Map<String, double> _gpaByKyHe4 = {};

  // ── Getters ─────────────────────────────
  List<DiemMonHoc> get diem => _diem;
  DiemSummary? get diemSummary => _diemSummary;
  bool get diemLoading => _diemState;

  double get gpa => _gpa;
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
        final rawList = result.diem
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
        await DatabaseService.updateCacheMeta('diem_all', 'synced');
      }

      // ── Load lại từ DB để đảm bảo data nhất quán ──
      _diem = await GradeDb.getDiem(); // ← Đọc từ DB thay vì result.diem

      if (result.latestSummary != null) {
        _diemSummary = result.latestSummary;
        await GradeDb.saveDiemSummary(result.latestSummary!);
      } else {
        _diemSummary = await GradeDb.loadDiemSummary();
      }

      _gpa = await GradeDb.calculateGPA();
      _totalCredits = await GradeDb.totalCreditsEarned();
      _gpaByKy = await GradeDb.getGPAByKy();
      _gpaByKyHe4 = await GradeDb.getGPAByKyHe4();

      // ← BUILD _diemByKy (bị thiếu hoàn toàn!)
      _diemByKy = {};
      for (final d in _diem) {
        final key = '${d.namHoc}_HK${d.hocKy}';
        _diemByKy.putIfAbsent(key, () => []).add(d);
      }

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

  Future<bool> voteAndRefreshDiem(String tenMonHoc, int mucDo, dynamic diemId,
      {String nhanXet = ''}) async {
    try {
      // B1: Lấy danh sách môn có thể vote
      final monList = await HauApiService.fetchMonCanVote();
      if (monList.isEmpty) return false;

      // B2: Match tên môn học (case-insensitive, trim)
      final tenNorm = tenMonHoc.toLowerCase().trim();
      final matched = monList.firstWhere(
        (m) =>
            m['ten']!.toLowerCase().trim().contains(tenNorm) ||
            tenNorm.contains(m['ten']!.toLowerCase().trim()),
        orElse: () => monList.first, // fallback môn đầu
      );
      final idMonTC = matched['id']!;

      // B3: Lấy IDLopTC
      final idLop = await HauApiService.fetchIdLopTC(idMonTC);
      if (idLop == null || idLop.isEmpty) return false;

      // B4: Lấy thông tin tiêu chí
      final info = await HauApiService.fetchTieuChiInfo(idMonTC, idLop);
      if (info == null) return false;

      // B5: Gửi kết quả
      final ok = await HauApiService.submitVote(
        idMonTC: idMonTC,
        idLopTC: idLop,
        mucDo: mucDo,
        countMax: info['countMax'] ?? 23,
        parentCount: info['parentCount'] ?? 4,
        nhanXet: nhanXet,
      );
      if (!ok) return false;

      // B6: Đánh dấu đã vote trong DB
      if (diemId is int) await GradeDb.markDaVote(diemId);

      // Reload danh sách từ DB
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
    _diem = await GradeDb.getDiem();
    _diemSummary = await GradeDb.loadDiemSummary(); // ← restore từ DB
    _gpa = await GradeDb.calculateGPA();
    _totalCredits = await GradeDb.totalCreditsEarned();
    _gpaByKy = await GradeDb.getGPAByKy(); // hệ 10
    _gpaByKyHe4 = await GradeDb.getGPAByKyHe4(); // hệ 4

    _diemByKy = {};
    for (final d in _diem) {
      final key = '${d.namHoc}_HK${d.hocKy}';
      _diemByKy.putIfAbsent(key, () => []).add(d);
    }

    notifyListeners();
  }

  // ── Initialization ──────────────────────

  Future<void> init() async {
    await refreshFromCache();
    await syncDiem();
  }
}
