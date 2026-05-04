import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/hau_api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';
import './schedule_provider.dart';
import './grade_provider.dart';
import './finance_provider.dart';
import '../services/local_notification_service.dart';

/// Keys for persistent login storage
const _kMssv = 'saved_mssv';
const _kPw = 'saved_pw';
const _kRemember = 'remember_login';

enum AuthState { unknown, loggedOut, loggedIn }

enum LoadState { idle, loading, success, error }

class AppProvider extends ChangeNotifier {
  // ── Composition: Include 3 sub-providers ────────────────────
  late ScheduleProvider scheduleProvider;
  late GradeProvider gradeProvider;
  late FinanceProvider financeProvider;

  // ── State ────────────────────────────────
  AuthState _authState = AuthState.unknown;
  String _currentMssv = '';
  String _authError = '';
  Student? _student;
  bool _isSyncing = false;
  bool _notifEnabled = false;
  int _curriculumMandatoryCredits = 144; // default fallback
  int _unreadNotifCount = 0;
  List<AppNotif> _notifications = []; // Reactive notification list

  // ── Getters ─────────────────────────────
  AuthState get authState => _authState;
  String get currentMssv => _currentMssv;
  String get authError => _authError;
  Student? get student => _student;
  bool get isSyncing => _isSyncing;
  bool get notifEnabled => _notifEnabled;
  int get curriculumTotalCredits => _curriculumMandatoryCredits;
  int get unreadNotifCount => _unreadNotifCount;
  List<AppNotif> get notifications => _notifications;

  // ── Constructor ─────────────────────────
  AppProvider() {
    scheduleProvider = ScheduleProvider();
    gradeProvider = GradeProvider();
    financeProvider = FinanceProvider();

    // Lắng nghe thay đổi từ sub-providers
    scheduleProvider.addListener(_onSubProviderChanged);
    gradeProvider.addListener(_onSubProviderChanged);
    financeProvider.addListener(_onSubProviderChanged);
  }

  void _onSubProviderChanged() {
    notifyListeners();
  }

  // ── Methods ─────────────────────────────

  Future<void> init() async {
    _authState = AuthState.unknown;
    notifyListeners();

    try {
      // Thử auto-login bằng credentials đã lưu
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRemember) ?? false;
      if (remember) {
        final mssv = prefs.getString(_kMssv) ?? '';
        final pw = prefs.getString(_kPw) ?? '';
        if (mssv.isNotEmpty && pw.isNotEmpty) {
          _currentMssv = mssv;
          await DatabaseService.setMssv(mssv);
          NotificationService.setMssv(mssv);
          gradeProvider.setMssv(mssv);
          scheduleProvider.setMssv(mssv);
          // Load notification state
          _notifEnabled = await LocalNotificationService.isNotificationEnabled(mssv);
          // Load cache trước khi login để show data ngay
          await _loadFromCache();
          _authState = AuthState.loggedIn;
          notifyListeners();
          // Login nền để lấy session mới
          final error = await HauApiService.login(mssv, pw);
          if (error == null) {
            await syncAll();
          }
          // Nếu login thất bại do mất mạng, vẫn giữ cached data
          return;
        }
      }

      final isLoggedIn = HauApiService.isLoggedIn;
      if (isLoggedIn) {
        _authState = AuthState.loggedIn;
        // NOTE: we might not know MSSV if we didn't save it and just check isLoggedIn
        await _loadFromCache();
        await _syncStudent();
      } else {
        _authState = AuthState.loggedOut;
      }
    } catch (e) {
      _authError = 'Lỗi khởi tạo: $e';
      _authState = AuthState.loggedOut;
    }
    notifyListeners();
  }

  Future<bool> login(String mssv, String password,
      {bool remember = false}) async {
    _authError = '';
    notifyListeners();

    try {
      final error = await HauApiService.login(mssv, password);

      if (error == null) {
        _currentMssv = mssv;
        await DatabaseService.setMssv(mssv);
        NotificationService.setMssv(mssv);
        gradeProvider.setMssv(mssv);
        scheduleProvider.setMssv(mssv);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kRemember, remember);
        if (remember) {
          await prefs.setString(_kMssv, mssv);
          await prefs.setString(_kPw, password);
        } else {
          await prefs.remove(_kMssv);
          await prefs.remove(_kPw);
        }

        // Vào app NGAY, sync chạy nền
        // Load notification state
        _notifEnabled =
            await LocalNotificationService.isNotificationEnabled(mssv);
        _authState = AuthState.loggedIn;
        notifyListeners();

        // Admin: seed + load cache NGAY (data là local, không cần chờ)
        if (mssv == 'admin') {
          await NotificationService.seedMockData();
          await _loadFromCache();
        }
        if (mssv == 'admin') {
          await HauApiService.seedAdminMockData();
          await NotificationService.seedMockData(); // Bổ sung seeding thông báo
          await _loadFromCache();
          await refreshNotifications(); // Ép buộc load thông báo vào state ngay lập tức
          notifyListeners();
        }

        // Sync nền — không await
        syncAll().then((_) => notifyListeners());
        // Đăng ký background sync định kỳ
        BackgroundSyncService.schedulePeriodicSync();
        return true;
      } else {
        _authState = AuthState.loggedOut;
        _authError = error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _authState = AuthState.loggedOut;
      _authError = 'Lỗi đăng nhập: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final mssvToDelete = _currentMssv;
      HauApiService.logout();

      // Xóa toàn bộ file DB của user này
      await DatabaseService.deleteCurrentUserDb();

      // Xóa saved credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kMssv);
      await prefs.remove(_kPw);
      await prefs.setBool(_kRemember, false);

      // Xóa thông báo đã lên lịch & hủy background sync
      await LocalNotificationService.setNotificationEnabled(
          mssvToDelete, false);
      await BackgroundSyncService.cancelAll();

      // Xóa data thông báo
      await NotificationService.clearAll();
      _unreadNotifCount = 0;
      _notifications = [];

      _authState = AuthState.loggedOut;
      _currentMssv = '';
      NotificationService.setMssv('');
      _student = null;
      _authError = '';

      // Reset sub-providers (xóa sạch data trong bộ nhớ)
      scheduleProvider.clearData();
      gradeProvider.clearData();
      financeProvider.clearData();
    } catch (e) {
      _authError = 'Lỗi đăng xuất: $e';
    }
    notifyListeners();
  }

  void setNotifEnabled(bool val) {
    _notifEnabled = val;
    notifyListeners();
  }

  Future<void> syncAll({bool forceRefresh = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final hasNet = await _checkNetwork();
      if (!hasNet) {
        debugPrint('📴 Offline - chỉ load từ cache');
        await _loadFromCache();
        return;
      }

      // Snapshot trước sync để detect thay đổi
      final prevDiemCount = gradeProvider.diem.length;
      final prevLichHocCount = scheduleProvider.lichHoc.length;
      final prevLichThiCount = scheduleProvider.lichThi.length;
      final prevDaDong = financeProvider.tongHocPhiDaDong;

      await Future.wait([
        _syncStudent(),
        scheduleProvider.syncLichHoc(forceRefresh: forceRefresh),
        scheduleProvider.syncLichThi(forceRefresh: forceRefresh),
        gradeProvider.syncDiem(forceRefresh: forceRefresh),
        financeProvider.syncHocPhi(forceRefresh: forceRefresh),
      ]);

      // Lên lịch thông báo sau khi sync xong
      await LocalNotificationService.scheduleClasses(
          _currentMssv, scheduleProvider.lichHoc, scheduleProvider.lichThi);

      // Phát hiện thay đổi và tạo thông báo
      await _detectAndNotify(
        prevDiemCount: prevDiemCount,
        prevLichHocCount: prevLichHocCount,
        prevLichThiCount: prevLichThiCount,
        prevDaDong: prevDaDong,
      );

      // Lưu lại thông báo vào UI nếu đã tới giờ
      await _detectAndNotifyDailySchedule();
    } catch (e) {
      debugPrint('⚠️ syncAll error: $e');
    } finally {
      _isSyncing = false;
      await refreshUnreadCount();
      notifyListeners(); // Đảm bảo icon quay sẽ dừng
    }
  }

  /// Tải lại danh sách thông báo và số unread vào state, kích hoạt rebuild UI.
  Future<void> refreshNotifications() async {
    final list = await NotificationService.getAll();
    final count = list.where((n) => !n.isRead).length;
    _notifications = list;
    _unreadNotifCount = count;
    _notifications = await NotificationService.getAll();
    _unreadNotifCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markNotifAsRead(String id) async {
    await NotificationService.markRead(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      _unreadNotifCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> removeNotif(String id) async {
    await NotificationService.removeOne(id);
    _notifications.removeWhere((n) => n.id == id);
    _unreadNotifCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> clearAllNotifs() async {
    await NotificationService.clearAll();
    _notifications.clear();
    _unreadNotifCount = 0;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    await refreshNotifications();
  }

  Future<void> _detectAndNotify({
    required int prevDiemCount,
    required int prevLichHocCount,
    required int prevLichThiCount,
    required double prevDaDong,
  }) async {
    final now = DateTime.now();
    final newDiemCount = gradeProvider.diem.length;
    final newLichHocCount = scheduleProvider.lichHoc.length;
    final newLichThiCount = scheduleProvider.lichThi.length;
    final newDaDong = financeProvider.tongHocPhiDaDong;

    // Đọc danh sách đã xóa 1 lần duy nhất để tối ưu hiệu năng
    final dismissed = await NotificationService.getDismissedIds();
    final allNotifs = await NotificationService.getAll();

    // 1. THÔNG BÁO ĐIỂM
    if (prevDiemCount > 0 && newDiemCount > prevDiemCount) {
      final diff = newDiemCount - prevDiemCount;
      final notifId = 'grade_to_$newDiemCount'; // ID ổn định dựa trên số lượng
      if (!dismissed.contains(notifId) &&
          !allNotifs.any((n) => n.id == notifId)) {
        final title = 'Có điểm mới';
        final body = 'Vừa có $diff môn học có điểm mới trên hệ thống tín chỉ.';
        await NotificationService.add(AppNotif(
          id: notifId,
          title: title,
          body: body,
          targetTab: 2,
          ts: now,
        ));
        await LocalNotificationService.showImmediate(
            id: 1001, title: title, body: body);
      }
    }

    // 2. THÔNG BÁO LỊCH HỌC
    if (prevLichHocCount > 0 && newLichHocCount > prevLichHocCount) {
      final notifId = 'lich_to_$newLichHocCount';
      if (!dismissed.contains(notifId) &&
          !allNotifs.any((n) => n.id == notifId)) {
        final title = 'Lịch học được cập nhật';
        final body =
            'Có ${newLichHocCount - prevLichHocCount} buổi học mới trong lịch';
        await NotificationService.add(AppNotif(
          id: notifId,
          title: title,
          body: body,
          targetTab: 1,
          ts: now,
        ));
        await LocalNotificationService.showImmediate(
            id: 1002, title: title, body: body);
      }
    }

    // 3. THÔNG BÁO LỊCH THI
    if (prevLichThiCount > 0 && newLichThiCount > prevLichThiCount) {
      final notifId = 'thi_to_$newLichThiCount';
      if (!dismissed.contains(notifId) &&
          !allNotifs.any((n) => n.id == notifId)) {
        final title = 'Có lịch thi mới';
        final body =
            '${newLichThiCount - prevLichThiCount} lịch thi vừa được thêm vào';
        await NotificationService.add(AppNotif(
          id: notifId,
          title: title,
          body: body,
          targetTab: 1,
          ts: now,
        ));
        await LocalNotificationService.showImmediate(
            id: 1003, title: title, body: body);
      }
    }

    // 4. THÔNG BÁO HỌC PHÍ
    if (prevDaDong > 0 && newDaDong > prevDaDong) {
      final notifId = 'finance_to_${newDaDong.toInt()}';
      if (!dismissed.contains(notifId) &&
          !allNotifs.any((n) => n.id == notifId)) {
        final title = 'Thanh toán được ghi nhận';
        final body = 'Học phí đã được cập nhật';
        await NotificationService.add(AppNotif(
          id: notifId,
          title: title,
          body: body,
          targetTab: 3,
          ts: now,
        ));
        await LocalNotificationService.showImmediate(
            id: 1004, title: title, body: body);
      }
    }
  }

  Future<void> _detectAndNotifyDailySchedule() async {
    final enabled =
        await LocalNotificationService.isNotificationEnabled(_currentMssv);
    if (!enabled) return;

    final now = DateTime.now();
    final dismissed = await NotificationService.getDismissedIds();
    final allNotifs = await NotificationService.getAll();

    // ── 1. THÔNG BÁO TỔNG HỢP 20:00 (ngày mai) ──
    for (int i = 1; i <= 1; i++) {
      final targetDate = now.add(Duration(days: i));
      final notifyAt = DateTime(now.year, now.month, now.day, 20, 0);
      if (now.isBefore(notifyAt)) continue;

      final classes = getLichHocForDate(targetDate);
      final exams = getLichThiForDate(targetDate);
      if (classes.isEmpty && exams.isEmpty) continue;

      final notifId =
          'schedule_reminder_${targetDate.year}_${targetDate.month}_${targetDate.day}';

      if (dismissed.contains(notifId)) continue;
      if (allNotifs.any((n) => n.id == notifId)) continue;

      String body = '';
      if (classes.isNotEmpty) body += '📚 ${classes.length} ca học';
      if (exams.isNotEmpty) {
        if (body.isNotEmpty) body += ' & ';
        body += '📝 ${exams.length} ca thi';
      }
      body += ' vào ngày mai. ';
      final details = <String>[];
      for (var c in classes) details.add('${c.tenHocPhan} (${c.gioHoc})');
      for (var e in exams) details.add('${e.tenMonHoc} (Thi - ${e.gioBatDau})');
      body += details.take(3).join(', ');
      if (details.length > 3)
        body += ' và ${details.length - 3} sự kiện khác...';

      await NotificationService.add(AppNotif(
        id: notifId,
        title: 'Nhắc nhở lịch học ngày mai',
        body: body,
        targetTab: 1,
        ts: notifyAt,
      ));
    }

    // ── 2. THÔNG BÁO TRƯỚC 1 TIẾNG TỪNG CA HỌC/THI (hôm nay + ngày mai) ──
    for (int i = 0; i <= 1; i++) {
      final targetDate = now.add(Duration(days: i));
      final classes = getLichHocForDate(targetDate);
      final exams = getLichThiForDate(targetDate);

      for (final c in classes) {
        final timeParts = c.gioHoc.split(':');
        if (timeParts.length != 2) continue;
        final h = int.tryParse(timeParts[0]) ?? 0;
        final m = int.tryParse(timeParts[1]) ?? 0;
        final classTime =
            DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
        final reminderTime = classTime.subtract(const Duration(hours: 1));

        // Chỉ add nếu đã đến giờ nhắc và chưa quá giờ học
        if (now.isBefore(reminderTime) || now.isAfter(classTime)) continue;

        final notifId =
            'class_reminder_${targetDate.year}_${targetDate.month}_${targetDate.day}_${c.tenHocPhan}';

        if (dismissed.contains(notifId)) continue;
        if (allNotifs.any((n) => n.id == notifId)) continue;

        await NotificationService.add(AppNotif(
          id: notifId,
          title: 'Sắp tới giờ học!',
          body:
              'Môn ${c.tenHocPhan} sẽ bắt đầu lúc ${c.gioHoc} tại phòng ${c.phong}.',
          targetTab: 1,
          ts: reminderTime,
        ));
      }

      for (final e in exams) {
        final timeParts = e.gioBatDau.split(':');
        if (timeParts.length != 2) continue;
        final h = int.tryParse(timeParts[0]) ?? 0;
        final m = int.tryParse(timeParts[1]) ?? 0;
        final examTime =
            DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
        final reminderTime = examTime.subtract(const Duration(hours: 1));

        if (now.isBefore(reminderTime) || now.isAfter(examTime)) continue;

        final notifId =
            'exam_reminder_${targetDate.year}_${targetDate.month}_${targetDate.day}_${e.tenMonHoc}';

        if (dismissed.contains(notifId)) continue;
        if (allNotifs.any((n) => n.id == notifId)) continue;

        await NotificationService.add(AppNotif(
          id: notifId,
          title: 'Sắp tới giờ thi!',
          body:
              'Môn ${e.tenMonHoc} sẽ thi lúc ${e.gioBatDau} tại phòng ${e.phong}.',
          targetTab: 1,
          ts: reminderTime,
        ));
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      if (_currentMssv.isNotEmpty) {
        _student = await DatabaseService.getStudent(_currentMssv);
        if (_student != null) _currentMssv = _student!.mssv;
      }
      await scheduleProvider.refreshFromCache();
      await gradeProvider.refreshFromCache();
      await financeProvider.refreshFromCache();
      // Load curriculum credits
      final prefs = await SharedPreferences.getInstance();
      _curriculumMandatoryCredits =
          prefs.getInt('curriculum_mandatory_tc') ?? 144;

      await _detectAndNotifyDailySchedule();

      // Load danh sách thông báo vào state (reactive)
      await refreshNotifications();
    } catch (e) {
      debugPrint('Lỗi tải cache: $e');
    }
  }

  Future<void> _syncStudent() async {
    try {
      final student = await HauApiService.fetchThongTinSinhVien();
      if (student != null) {
        _student = student;
        _currentMssv = student.mssv;
        await DatabaseService.setMssv(_currentMssv);
        NotificationService.setMssv(_currentMssv);
        gradeProvider.setMssv(_currentMssv);
        scheduleProvider.setMssv(_currentMssv);
        await DatabaseService.saveStudent(student);
      }
    } catch (e) {
      debugPrint('Lỗi sync student: $e');
    }
  }

  // Schedule
  LoadState get lichHocState =>
      scheduleProvider.lichHocLoading ? LoadState.loading : LoadState.idle;
  LoadState get lichThiState =>
      scheduleProvider.lichThiLoading ? LoadState.loading : LoadState.idle;
  int get currentHocKy => scheduleProvider.currentHocKy;
  int get currentNamHoc => scheduleProvider.currentNamHoc;
  int get currentDotHoc => scheduleProvider.currentDotHoc;
  int get currentCN => scheduleProvider.currentCN;
  String get namHocLabel => scheduleProvider.namHocLabel;
  List<LichHoc> get lichHoc => scheduleProvider.lichHoc;
  List<LichThi> get lichThi => scheduleProvider.lichThi;

  // Grade
  LoadState get diemState =>
      gradeProvider.diemLoading ? LoadState.loading : LoadState.idle;
  double get gpa => gradeProvider.gpa;
  double get gpaHe4 => gradeProvider.gpaHe4;
  int get totalCredits => gradeProvider.totalCredits;
  Map<String, double> get gpaByKy => gradeProvider.gpaByKy;
  Map<String, List<DiemMonHoc>> get diemByKy => gradeProvider.diemByKy;
  Map<String, double> get gpaByKyHe4 => gradeProvider.gpaByKyHe4;
  List<DiemMonHoc> get diem => gradeProvider.diem;
  List<DiemMonHoc> get diemOverview => gradeProvider.diemOverview;
  DiemSummary? get diemSummary => gradeProvider.diemSummary;
  Map<String, DiemSummary> get semesterSummaries =>
      gradeProvider.semesterSummaries;

  // Finance
  LoadState get hocPhiState =>
      financeProvider.hocPhiLoading ? LoadState.loading : LoadState.idle;
  List<Map<String, Object?>> get paymentReceipts =>
      financeProvider.paymentReceipts;
  List<Map<String, Object?>> get feeDetails => financeProvider.feeDetails;
  List<Map<String, Object?>> get feeSummaries => financeProvider.feeSummaries;
  double get tongHocPhiPhaiDong => financeProvider.tongHocPhiPhaiDong;
  double get tongHocPhiDaDong => financeProvider.tongHocPhiDaDong;
  double get tongHocPhiConLai => financeProvider.tongHocPhiConLai;
  double get progressHocPhi => financeProvider.progressHocPhi;

  // All-time totals
  double get tongHocPhiAllTerms => financeProvider.tongHocPhiAllTerms;
  String? get tongThieuHocPhi => financeProvider.tongThieuHocPhi;
  double get tongHocPhiAllPhaiDong => financeProvider.tongHocPhiPhaiDong;
  double get tongHocPhiAllDaDong => financeProvider.tongHocPhiDaDong;
  double get tongHocPhiAllConLai => financeProvider.tongHocPhiConLai;
  double get progressHocPhiAll => tongHocPhiAllPhaiDong > 0
      ? (tongHocPhiAllDaDong / tongHocPhiAllPhaiDong).clamp(0.0, 1.0)
      : 0.0;

  // ── Backward Compatibility Methods ──────────────────────────

  List<LichHoc> getLichHocHomNay() => scheduleProvider.getLichHocHomNay();
  List<LichThi> getUpcomingExams({int daysAhead = 7}) =>
      scheduleProvider.getUpcomingExams(daysAhead: daysAhead);
  List<LichHoc> getLichHocForDate(DateTime date) =>
      scheduleProvider.getLichHocForDate(date);
  List<LichThi> getLichThiForDate(DateTime date) =>
      scheduleProvider.getLichThiForDate(date);

  Future<bool> voteAndRefreshDiem(
    String tenMonHoc,
    int mucDo,
    dynamic diemId, {
    String nhanXet = '',
    String? maMonHoc,
  }) =>
      gradeProvider.voteAndRefreshDiem(
        tenMonHoc,
        mucDo,
        diemId,
        nhanXet: nhanXet,
        maMonHoc: maMonHoc,
      );

  /// Chỉ đồng bộ điểm (dùng cho RefreshIndicator trang Điểm)
  Future<void> syncGrades({bool forceRefresh = true}) =>
      gradeProvider.syncDiem(forceRefresh: forceRefresh);

  /// Chỉ đồng bộ lịch học + lịch thi (dùng cho RefreshIndicator trang Lịch)
  Future<void> syncSchedule({bool forceRefresh = true}) => Future.wait([
        scheduleProvider.syncLichHoc(forceRefresh: forceRefresh),
        scheduleProvider.syncLichThi(forceRefresh: forceRefresh),
      ]).then((_) async {
        // Chỉ lên lịch thông báo nếu người dùng đã bật
        if (_notifEnabled) {
          await LocalNotificationService.scheduleClasses(
              _currentMssv, scheduleProvider.lichHoc, scheduleProvider.lichThi);
        } else {
          // Nếu tắt, đảm bảo hủy hết lịch cũ
          await LocalNotificationService.cancelAll();
        }
      });

  /// Chỉ đồng bộ học phí (dùng cho RefreshIndicator trang Tài chính)
  Future<void> syncFinance({bool forceRefresh = true}) =>
      financeProvider.syncHocPhi(forceRefresh: forceRefresh);

  Future<void> changeHocKy(int hocKy) => scheduleProvider.changeHocKy(hocKy);
  Future<void> changeNamHoc(int year) => scheduleProvider.changeNamHoc(year);
  Future<void> changeDotHoc(int dot) => scheduleProvider.changeDotHoc(dot);
  Future<void> changeCN(int cn) => scheduleProvider.changeCN(cn);

  /// Lưu tổng tín chỉ bắt buộc từ chương trình đào tạo
  Future<void> setCurriculumMandatoryCredits(int tc) async {
    if (tc <= 0) return;
    _curriculumMandatoryCredits = tc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('curriculum_mandatory_tc', tc);
    notifyListeners();
  }

  // ── Cleanup ──────────────────────────────
  @override
  void dispose() {
    scheduleProvider.dispose();
    gradeProvider.dispose();
    financeProvider.dispose();
    super.dispose();
  }

  // ── Network check ─────────────────────────
  Future<bool> _checkNetwork() async {
    try {
      final r = await http
          .head(Uri.parse(HauApiService.base))
          .timeout(const Duration(seconds: 5));
      return r.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
