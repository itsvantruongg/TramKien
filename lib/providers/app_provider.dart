import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
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

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
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
  DateTime?
      _lastSyncTime; // Theo dõi lần sync cuối để tránh sync quá thường xuyên

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

    // Đăng ký lắng nghe trạng thái vòng đời của ứng dụng
    WidgetsBinding.instance.addObserver(this);

    // Chạy init() SAU KHI UI đã dựng xong frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      init();
    });
  }

  void _onSubProviderChanged() {
    notifyListeners();
  }

  // ── Methods ─────────────────────────────

  Future<void> init() async {
    _authState = AuthState.unknown;
    notifyListeners();

    try {
      // Preload hai bộ font chính (Manrope & Inter) trong lúc Splash Screen đang hiển thị
      await GoogleFonts.pendingFonts([
        GoogleFonts.manrope(),
        GoogleFonts.inter(),
      ]);

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
          await NotificationService.ensureNotifStartTime(mssv);
          gradeProvider.setMssv(mssv);
          scheduleProvider.setMssv(mssv);
          // Load notification state
          _notifEnabled =
              await LocalNotificationService.isNotificationEnabled(mssv);
          // Load cache trước khi login để show data ngay
          await _loadFromCache();
          _authState = AuthState.loggedIn;
          notifyListeners();

          // Login nền và sync ngầm ở background, KHÔNG await làm đơ UI frame 1
          unawaited(_asyncBackgroundLoginAndSync(mssv, pw, prefs));
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
        // Đảm bảo Splash Screen hiển thị mượt mà tối thiểu 400ms, tránh chớp nháy 16ms
        await Future.delayed(const Duration(milliseconds: 400));
        _authState = AuthState.loggedOut;
      }
    } catch (e) {
      _authError = 'Lỗi khởi tạo: $e';
      _authState = AuthState.loggedOut;
    }
    notifyListeners();
  }

  Future<void> _asyncBackgroundLoginAndSync(
      String mssv, String pw, SharedPreferences prefs) async {
    try {
      final error = await HauApiService.login(mssv, pw);
      if (error == null) {
        // [B2 Reconcile] Kiểm tra trực tiếp fetched_app_version trong các bản ghi SQLite
        final currentVer = DatabaseService.currentAppVersion;
        final bool needsDbReconcile =
            await ScheduleDb.needsReconcile(currentVer);
        final lastReconciledVer =
            prefs.getString('last_reconciled_app_version');
        final bool needsReconcile =
            needsDbReconcile || (lastReconciledVer != currentVer);
        if (needsReconcile) {
          debugPrint(
              '🔄 [Reconcile] Phát hiện bản ghi DB có fetched_app_version != $currentVer (hoặc NULL) → Ép sync full & diff-delete');
        }
        await syncAll(forceRefresh: needsReconcile);
        await prefs.setString('last_reconciled_app_version', currentVer);

        // [B5] Chỉ đăng ký periodic sync sau khi đăng nhập thành công
        await BackgroundSyncService.schedulePeriodicSync();
      }
    } catch (e) {
      debugPrint('⚠️ Lỗi background login & sync: $e');
    }
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
        await NotificationService.ensureNotifStartTime(mssv);
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
      await prefs.remove('notif_start_time_$mssvToDelete');

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
    final acquired = await SyncMutex.acquireLock(_currentMssv);
    if (_isSyncing || BackgroundSyncService.isSyncing || !acquired) {
      debugPrint('⚙️ [AppProvider] Sync bị hoãn do sync/BG sync đang chạy (Mutex active)');
      return;
    }
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

      // Sinh thẻ thông báo lịch học/thi (cho cả quá khứ/catch-up và tương lai)
      await LocalNotificationService.generateScheduleCards(
          _currentMssv, scheduleProvider.lichHoc, scheduleProvider.lichThi);
    } catch (e) {
      debugPrint('⚠️ syncAll error: $e');
    } finally {
      _isSyncing = false;
      await SyncMutex.releaseLock(_currentMssv);
      _lastSyncTime = DateTime.now(); // Cập nhật thời điểm sync xong
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
    // Chỉ thông báo khi:
    //   - prevDiemCount > 0: đã có data trong bộ nhớ trước khi sync (không phải lần đầu tiên)
    //   - newDiemCount > prevDiemCount: thực sự có thêm môn học mới
    // Lưu ý: prevDiemCount == 0 xảy ra khi cache chưa load HOẶC lần đăng nhập đầu tiên.
    // Không thông báo trong trường hợp này để tránh "44 môn mới" giả tạo khi vào app lần đầu.
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

  // Các phương thức sinh thẻ thông báo lịch học/thi cũ đã được chuyển sang LocalNotificationService.generateScheduleCards

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

      // Sinh thẻ thông báo lịch học/thi (cho cả quá khứ/catch-up và tương lai) ngầm ở background
      unawaited(LocalNotificationService.generateScheduleCards(
          _currentMssv, scheduleProvider.lichHoc, scheduleProvider.lichThi));

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
  List<LichHoc> getLichHocNgayMai() => scheduleProvider.getLichHocNgayMai();
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
  Future<void> syncGrades({bool forceRefresh = true}) async {
    // Snapshot trước sync để detect thay đổi điểm
    final prevDiemCount = gradeProvider.diem.length;

    await gradeProvider.syncDiem(forceRefresh: forceRefresh);

    // Phát hiện và thông báo nếu có điểm mới
    await _detectAndNotify(
      prevDiemCount: prevDiemCount,
      prevLichHocCount: scheduleProvider.lichHoc.length, // không thay đổi
      prevLichThiCount: scheduleProvider.lichThi.length, // không thay đổi
      prevDaDong: financeProvider.tongHocPhiDaDong, // không thay đổi
    );
    await refreshUnreadCount();
    notifyListeners();
  }

  /// Chỉ đồng bộ lịch học + lịch thi (dùng cho RefreshIndicator trang Lịch)
  Future<void> syncSchedule({bool forceRefresh = true}) async {
    // Snapshot trước sync để detect thay đổi
    final prevLichHocCount = scheduleProvider.lichHoc.length;
    final prevLichThiCount = scheduleProvider.lichThi.length;

    await Future.wait([
      scheduleProvider.syncLichHoc(forceRefresh: forceRefresh),
      scheduleProvider.syncLichThi(forceRefresh: forceRefresh),
    ]);

    // Lên lịch push notification (local alarm)
    if (_notifEnabled) {
      await LocalNotificationService.scheduleClasses(
          _currentMssv, scheduleProvider.lichHoc, scheduleProvider.lichThi);
    } else {
      await LocalNotificationService.cancelAll();
    }

    // Phát hiện và thông báo in-app nếu có lịch mới
    await _detectAndNotify(
      prevDiemCount: gradeProvider.diem.length, // không thay đổi
      prevLichHocCount: prevLichHocCount,
      prevLichThiCount: prevLichThiCount,
      prevDaDong: financeProvider.tongHocPhiDaDong, // không thay đổi
    );
    await refreshUnreadCount();
    notifyListeners();
  }

  /// Chỉ đồng bộ học phí (dùng cho RefreshIndicator trang Tài chính)
  Future<void> syncFinance({bool forceRefresh = true}) async {
    // Snapshot trước sync để detect thay đổi
    final prevDaDong = financeProvider.tongHocPhiDaDong;

    await financeProvider.syncHocPhi(forceRefresh: forceRefresh);

    // Phát hiện và thông báo in-app nếu có cập nhật học phí
    await _detectAndNotify(
      prevDiemCount: gradeProvider.diem.length, // không thay đổi
      prevLichHocCount: scheduleProvider.lichHoc.length, // không thay đổi
      prevLichThiCount: scheduleProvider.lichThi.length, // không thay đổi
      prevDaDong: prevDaDong,
    );
    await refreshUnreadCount();
    notifyListeners();
  }

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
    WidgetsBinding.instance
        .removeObserver(this); // Hủy đăng ký lifecycle observer
    scheduleProvider.dispose();
    gradeProvider.dispose();
    financeProvider.dispose();
    super.dispose();
  }

  /// Lắng nghe trạng thái vòng đời của ứng dụng.
  /// Khi user mở lại app từ nền (resumed), reload lại cache để:
  ///   1. Đồng bộ SharedPreferences (vì getAll/getDismissedIds đã gọi prefs.reload()).
  ///   2. Nạp lại dữ liệu SQLite mới nhất vào RAM của các Provider,
  ///      giúp prevCount trong syncAll() luôn khớp thực tế — tránh thông báo trùng lặp.
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[⚡ Resume] App mở lại — đang làm mới cache từ SQLite...');
      try {
        if (_currentMssv.isNotEmpty) {
          await _loadFromCache();
          // Lưu ý: _loadFromCache() đã gọi generateScheduleCards() bên trong,
          // nên thẻ thông báo lịch học/thi luôn được bù và cập nhật dù mạng chập chờn.

          // Sync API lại nếu đã hơn 30 phút kể từ lần sync cuối
          // (tránh sync liên tục khi user chỉ switch app nhanh)
          final now = DateTime.now();
          final shouldSync = _lastSyncTime == null ||
              now.difference(_lastSyncTime!) > const Duration(minutes: 30);

          if (shouldSync && !_isSyncing) {
            debugPrint('[⚡ Resume] Đã lâu hơn 30 phút — tiến hành sync API...');
            // Chạy nền, không await để không block UI
            syncAll(forceRefresh: true).then((_) {
              debugPrint('[⚡ Resume] Sync hoàn tất sau khi resume');
            });
          } else {
            debugPrint('[⚡ Resume] Sync gần đây (< 30 phút), bỏ qua fetch API');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Lỗi làm mới cache khi resume: $e');
      }
    }
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
