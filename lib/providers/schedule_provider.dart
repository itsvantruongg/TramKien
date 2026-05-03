import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/hau_api_service.dart';
import '../services/database_service.dart';
import '../services/api/schedule_api.dart';
import '../services/db/schedule_db.dart';

class ScheduleProvider extends ChangeNotifier {
  // ── Constants ────────────────────────────
  static const List<int> allHocKy = [1, 2];
  static const List<int> allNamHoc = [2024, 2025, 2026];
  static const List<int> allDotHoc = [1, 2, 3, 4, 5, 6, 7, 8];
  static const Duration _ttlLichHoc = Duration(hours: 6);
  static const Duration _ttlLichThi = Duration(hours: 24);

  // ── State ────────────────────────────────
  List<LichHoc> _lichHoc = [];
  List<LichThi> _lichThi = [];
  bool _lichHocState = false;
  bool _lichThiState = false;
  String? _mssv; // ← thêm để tính startYear

  late int _currentHocKy;
  late int _currentNamHoc;
  int _currentDotHoc = 1;
  int _currentCN = 0;

  // ── Set MSSV (gọi từ AppProvider sau login) ──
  void setMssv(String? mssv) {
    _mssv = mssv;
  }

  // Xóa toàn bộ data trong bộ nhớ (gọi khi logout)
  void clearData() {
    _lichHoc = [];
    _lichThi = [];
    _mssv = null;
    notifyListeners();
  }

  // ── Auto-detect HK từ ngày hiện tại ──────
  static ({int hocKy, int namHoc}) detectCurrentSemester() {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    if (month >= 8) {
      return (hocKy: 1, namHoc: year);
    } else if (month == 1) {
      return (hocKy: 1, namHoc: year - 1);
    } else {
      return (hocKy: 2, namHoc: year - 1);
    }
  }

  // ── Getters ─────────────────────────────
  List<LichHoc> get lichHoc => _lichHoc;
  List<LichThi> get lichThi => _lichThi;
  bool get lichHocLoading => _lichHocState;
  bool get lichThiLoading => _lichThiState;
  int get currentHocKy => _currentHocKy;
  int get currentNamHoc => _currentNamHoc;
  int get currentDotHoc => _currentDotHoc;
  int get currentCN => _currentCN;
  String get namHocLabel => '$_currentNamHoc-${_currentNamHoc + 1}';

  ScheduleProvider() {
    final sem = detectCurrentSemester();
    _currentHocKy = sem.hocKy;
    _currentNamHoc = sem.namHoc;
  }

  Future<void> changeHocKy(int hocKy) async {
    if (_currentHocKy == hocKy) return;
    _currentHocKy = hocKy;
    await _filterFromDb();
    notifyListeners();
  }

  Future<void> changeNamHoc(int namHoc) async {
    if (_currentNamHoc == namHoc) return;
    _currentNamHoc = namHoc;
    await _filterFromDb();
    notifyListeners();
  }

  Future<void> changeDotHoc(int dotHoc) async {
    if (_currentDotHoc == dotHoc) return;
    _currentDotHoc = dotHoc;
    _lichHoc = await ScheduleDb.getLichHoc(
        hocKy: _currentHocKy, namHoc: namHocLabel, dotHoc: dotHoc);
    notifyListeners();
  }

  Future<void> changeCN(int cn) async {
    if (_currentCN == cn) return;
    _currentCN = cn;
    notifyListeners();
  }

  // Lọc từ DB theo kỳ hiện tại (không fetch lại API)
  Future<void> _filterFromDb() async {
    // Giữ nguyên load tất cả — filter theo ngày tự động qua thoiGian
    _lichHoc = await ScheduleDb.getLichHoc();
    _lichThi = await ScheduleDb.getLichThi();
    notifyListeners();
  }

  Future<void> refreshFromCache() async {
    // Load tất cả lịch học (không filter kỳ) để _lichHocMatchesDate hoạt động đúng
    _lichHoc = await ScheduleDb.getLichHoc(); // ← không truyền hocKy/namHoc
    // Load lịch thi tất cả kỳ
    _lichThi = await ScheduleDb.getLichThi();

    print('📚 [Cache] Loaded: ${_lichHoc.length} lịch học, '
        '${_lichThi.length} lịch thi từ DB');
    notifyListeners();
  }

  /// Sync lịch học TẤT CẢ kỳ từ năm bắt đầu → hiện tại
  Future<void> syncLichHoc({bool forceRefresh = false}) async {
    _lichHocState = true;
    notifyListeners();
    try {
      // Xác định HK hiện tại
      final now = DateTime.now();
      final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;
      final currentHocKy = now.month >= 8 ? 1 : 2;
      final currentKey = 'lich_hoc_hk${currentHocKy}_${currentNamHoc}';

      // Các HK cũ → dùng cache dài hạn (7 ngày)
      final oldCacheKey = 'lich_hoc_old_${_mssv ?? "anon"}';
      final oldIsCached = !forceRefresh &&
          !(await DatabaseService.isStale(
              oldCacheKey, const Duration(days: 7)));

      // HK hiện tại → cache ngắn hơn (2 tiếng) để bắt kịp cập nhật mới
      final currentIsCached = !forceRefresh &&
          !(await DatabaseService.isStale(
              currentKey, const Duration(hours: 2)));

      if (oldIsCached && currentIsCached) {
        await refreshFromCache();
        print('📚 [LichHoc] Dùng cache, skip fetch API');
        return;
      }

      final result =
          await ScheduleApi.fetchLichHocFromStartWithStatus(mssv: _mssv);

      if (result.items.isNotEmpty) {
        await ScheduleDb.saveLichHoc(result.items);
        print('📚 [LichHoc] Đã lưu ${result.items.length} bản ghi vào DB');
      }

      if (result.complete) {
        await DatabaseService.updateCacheMeta(oldCacheKey, 'synced');
        await DatabaseService.updateCacheMeta(currentKey, 'synced');
      } else {
        print('⚠️ [LichHoc] Sync chưa đầy đủ, chưa đánh dấu cache synced');
      }

      await refreshFromCache();
    } catch (e) {
      print('❌ [LichHoc] syncLichHoc lỗi: $e');
    } finally {
      _lichHocState = false;
      notifyListeners();
    }
  }

  /// Sync lịch thi TẤT CẢ kỳ từ năm bắt đầu → hiện tại
  Future<void> syncLichThi({bool forceRefresh = false}) async {
    _lichThiState = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final startYear =
          _mssv != null ? HauApiService.getNamBatDauFromMssv(_mssv!) : 2020;
      final currentNamHoc = now.month >= 8 ? now.year : now.year - 1;

      // Fetch TẤT CẢ kỳ, không skip
      final kyList = <({int ky, int nam})>[];
      for (int nam = startYear; nam <= currentNamHoc; nam++) {
        kyList.add((ky: 1, nam: nam));
        kyList.add((ky: 2, nam: nam));
      }

      print('🗓️ [LichThi] mssv=$_mssv startYear=$startYear '
          '→ ${kyList.length} kỳ cần fetch (không skip)');

      bool allCached = !forceRefresh;
      if (allCached) {
        for (final k in kyList) {
          final cacheKey = 'lich_thi_${k.ky}_${k.nam}';
          final isCached = !(await DatabaseService.isStale(
              cacheKey, _ttlLichThi));
          if (!isCached) {
            allCached = false;
            break;
          }
        }
      }

      if (allCached) {
        await refreshFromCache();
        print('🗓️ [LichThi] Dùng cache, skip fetch API');
        return;
      }

      final result =
          await ScheduleApi.fetchLichThiFromStartWithStatus(mssv: _mssv);

      if (result.items.isNotEmpty) {
        await ScheduleDb.saveLichThi(result.items);
      }

      if (result.complete) {
        for (final k in kyList) {
          final cacheKey = 'lich_thi_${k.ky}_${k.nam}';
          await DatabaseService.updateCacheMeta(cacheKey, 'synced');
        }
      } else {
        print('⚠️ [LichThi] Sync chưa đầy đủ, chưa đánh dấu cache synced');
      }

      print('🏁 [LichThi] Tổng: ${result.items.length} lịch thi '
          'complete=${result.complete}');
      _lichThi = await ScheduleDb.getLichThi();
      notifyListeners();
    } catch (e) {
      print('❌ [LichThi] syncLichThi lỗi: $e');
    } finally {
      _lichThiState = false;
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────

  List<LichHoc> getLichHocByThu(String thu) {
    return _lichHoc.where((l) => l.thu == thu || l.thu == 'Thứ $thu').toList();
  }

  bool _lichHocMatchesDate(LichHoc l, DateTime date) {
    final thuStr = l.thu.replaceAll('Thứ', '').trim();
    final thuNum = int.tryParse(thuStr);
    if (thuNum == null || thuNum < 2 || thuNum > 8) return false;
    final expectedWeekday = thuNum == 8 ? 7 : thuNum - 1;
    if (date.weekday != expectedWeekday) return false;

    final tg = l.thoiGian.trim();
    final sepIdx = tg.indexOf('-', 10);
    if (sepIdx < 0) return false;

    final startStr = tg.substring(0, sepIdx).trim();
    final endStr = tg.substring(sepIdx + 1).trim();

    DateTime? parseDMY(String s) {
      final p = s.split('/');
      if (p.length == 3) {
        return DateTime.tryParse(
            '${p[2].padLeft(4, '0')}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
      }
      return null;
    }

    final start = parseDMY(startStr);
    final end = parseDMY(endStr);
    if (start == null || end == null) return false;

    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  List<LichHoc> getLichHocForDate(DateTime date) {
    return _lichHoc.where((l) => _lichHocMatchesDate(l, date)).toList();
  }

  List<LichThi> getLichThiForDate(DateTime date) {
    // DB lưu dạng "07/04/2026" (có padding 0) hoặc "7/4/2026" (không padding)
    // → so sánh bằng cách parse ngày thay vì so chuỗi
    return _lichThi.where((l) {
      final examDate = _parseDate(l.ngayThi);
      if (examDate == null) return false;
      return examDate.year == date.year &&
          examDate.month == date.month &&
          examDate.day == date.day;
    }).toList();
  }

  List<LichHoc> getLichHocHomNay() => getLichHocForDate(DateTime.now());

  List<LichThi> getUpcomingExams({int daysAhead = 7}) {
    final now = DateTime.now();
    final deadline = now.add(Duration(days: daysAhead));
    return _lichThi.where((l) {
      final examDate = _parseDate(l.ngayThi);
      return examDate != null &&
          examDate.isAfter(now) &&
          examDate.isBefore(deadline);
    }).toList();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  // ── Initialization ──────────────────────

  Future<void> init() async {
    final sem = detectCurrentSemester();
    _currentHocKy = sem.hocKy;
    _currentNamHoc = sem.namHoc;
    await refreshFromCache();
    await syncLichHoc();
    await syncLichThi();
  }

  // ── Manual Entries & Notes ───────────────

  Future<void> addManualLichHoc(LichHoc item) async {
    await ScheduleDb.insertManualLichHoc(item);
    await refreshFromCache();
  }

  Future<void> addManualLichThi(LichThi item) async {
    await ScheduleDb.insertManualLichThi(item);
    await refreshFromCache();
  }

  Future<void> updateNoteLichHoc(int id, String note) async {
    await ScheduleDb.updateLichHocNote(id, note);
    // Cập nhật local state nhanh
    final idx = _lichHoc.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _lichHoc[idx] = _lichHoc[idx].copyWith(note: note);
      notifyListeners();
    }
  }

  Future<void> updateNoteLichThi(int id, String note) async {
    await ScheduleDb.updateLichThiNote(id, note);
    // Cập nhật local state nhanh
    final idx = _lichThi.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _lichThi[idx] = _lichThi[idx].copyWith(note: note);
      notifyListeners();
    }
  }

  Future<void> deleteManualLichHoc(int id) async {
    await ScheduleDb.deleteManualLichHoc(id);
    await refreshFromCache();
  }

  Future<void> deleteManualLichThi(int id) async {
    await ScheduleDb.deleteManualLichThi(id);
    await refreshFromCache();
  }
}
