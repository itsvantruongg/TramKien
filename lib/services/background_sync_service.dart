import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'package:background_fetch/background_fetch.dart' as bf;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'hau_api_service.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';
import 'database_service.dart';
import '../models/models.dart';

/// Tên task
const kBgSyncTaskName = 'tramkien_bg_sync';
const kBgSyncTaskUniqueName = 'tramkien_periodic_sync';
const kBgFetchTaskId = 'com.tramkien.bgsync';

/// [DEBUG ONLY] Flag inject lỗi giả lập mất mạng — CHỈ bật khi mssv=='admin' && kDebugMode
/// Được set bởi DebugSyncScreen qua SharedPreferences key 'debug_fault_inject'
bool _debugFaultInjectActive = false;

// ──────────────────────────────────────────────────────────────
//  ANDROID: Workmanager entry-point (top-level, @pragma required)
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  wm.Workmanager().executeTask((taskName, inputData) async {
    // B8/Doze: ghi timestamp mỗi lần OS thực sự gọi vào job
    // So sánh với 'bg_last_attempted_at' để phát hiện delay do Doze/pin yếu
    final invokedAt = DateTime.now().toIso8601String();
    debugPrint('⚙️ [Android BG] Task: $taskName | OS invoked at: $invokedAt');
    await _runSyncLogic();
    return true;
  });
}

// ──────────────────────────────────────────────────────────────
//  iOS: background_fetch headless task entry-point
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(bf.HeadlessTask task) async {
  final taskId = task.taskId;
  final isTimeout = task.timeout;

  debugPrint('⚙️ [iOS BG] Headless task: $taskId | timeout: $isTimeout');

  if (isTimeout) {
    // iOS yêu cầu phải finish ngay khi timeout để tránh bị kill
    bf.BackgroundFetch.finish(taskId);
    return;
  }

  await _runSyncLogic();
  bf.BackgroundFetch.finish(taskId);
}

// ──────────────────────────────────────────────────────────────
//  Logic đồng bộ dùng chung cho cả 2 platform
// ──────────────────────────────────────────────────────────────

Future<void> _runSyncLogic() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  if (BackgroundSyncService.isSyncing) {
    debugPrint(
        '⚙️ [BG] Task đã đang chạy ở isolate hiện tại, bỏ qua (isSyncing flag).');
    return;
  }

  // ── Đọc MSSV sơ bộ từ SharedPreferences chỉ để check Admin & lấy lock ban đầu
  // LƯU Ý: Biến này CHỈ dùng trước Step 1. Sau Step 1 BẮT BUỘC dùng bgMssv.
  final _preCheckMssv = prefs.getString('saved_mssv') ?? '';
  String activeSyncMssv = _preCheckMssv;

  final acquired = await SyncMutex.acquireLock(_preCheckMssv);
  if (!acquired) {
    debugPrint(
        '⚙️ [BG] Persistent lock đang active ở isolate/process khác, bỏ qua lần gọi này.');
    return;
  }

  BackgroundSyncService._setSyncing(true);
  debugPrint('⚙️ [BG] Task bắt đầu chạy...');

  try {
    // Ghi timestamp nỗ lực thực thi (B8 - theo dõi deferment)
    await prefs.setString(
        'bg_last_attempted_at', DateTime.now().toIso8601String());

    // 1. Đọc credentials từ Secure Storage (Bug 4 Fix)
    // KHÔNG fallback về SharedPreferences — hai kho lưu trữ hoàn toàn tách biệt
    // SharedPreferences: autofill UI (remember login checkbox)
    // FlutterSecureStorage: consent đồng bộ nền (bg sync toggle)
    String bgMssv;
    String pw;

    if (_preCheckMssv == 'admin') {
      // Admin mode: không cần Secure Storage
      bgMssv = 'admin';
      pw = 'admin@123';
    } else {
      final creds = await BgCredentials.load();
      if (creds == null) {
        debugPrint(
            '⚙️ [BG][Step1-Credentials] Secure Storage rỗng → dừng sync '
            '(consent "Đồng bộ nền" chưa được cấp hoặc đã xóa)');
        return; // KHÔNG đọc SharedPreferences
      }
      bgMssv = creds.mssv;
      pw = creds.pw;
    }
    // Cập nhật activeSyncMssv sang danh tính thực tế từ Secure Storage
    activeSyncMssv = bgMssv;

    // 2. Khởi tạo service (dùng bgMssv chuẩn xác, không dùng SharedPreferences)
    try {
      await LocalNotificationService.init();
      NotificationService.setMssv(bgMssv);
      await DatabaseService.setMssv(bgMssv);
    } catch (e) {
      debugPrint(
          '⚠️ [BG][Step2-Init] Lỗi khởi tạo DB & Notification Services: $e');
      return;
    }

    // 3. Kiểm tra mạng
    try {
      if (!await _checkNetwork()) {
        debugPrint('⚙️ [BG][Step3-NetworkCheck] Offline – bỏ qua sync');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [BG][Step3-NetworkCheck] Lỗi kiểm tra kết nối mạng: $e');
      return;
    }

    // 4. Login lấy session mới (Bug 8: phân loại dựa trên HTTP 302 message từ API)
    const _kFailCountKey = 'bg_login_fail_count';
    const _kMaxFails = 3;

    // Lỗi mạng hoặc exception nội bộ client
    bool isNetworkOrTimeout(String err) {
      return err == 'Không có kết nối mạng' || err.startsWith('Lỗi: ');
    }

    try {
      final loginError = await HauApiService.login(bgMssv, pw);
      if (loginError == null) {
        // Thành công → reset bộ đếm fail
        await prefs.remove(_kFailCountKey);
      } else {
        final isNetErr = isNetworkOrTimeout(loginError);
        // Nếu không phải lỗi mạng/timeout thì chắc chắn là lỗi xác thực trả về từ HTTP 302 (?message=...)
        final isAuthErr = !isNetErr;

        final failCount = (prefs.getInt(_kFailCountKey) ?? 0) + 1;
        await prefs.setInt(_kFailCountKey, failCount);
        debugPrint(
            '⚠️ [BG][Step4-Login] Fail #$failCount: "$loginError" isAuth=$isAuthErr');

        if (isAuthErr || failCount >= _kMaxFails) {
          await BackgroundSyncService.cancelAll();
          await BgCredentials.clear(); // Xóa credentials không còn hợp lệ
          await LocalNotificationService.showImmediate(
            id: 9998,
            title: 'Đồng bộ nền đã dừng',
            body: isAuthErr
                ? '$loginError. Mở app để đăng nhập lại.'
                : 'Không thể kết nối sau $failCount lần thử. Mở app để kiểm tra.',
          );
          await prefs.remove(_kFailCountKey);
        }
        return;
      }
    } catch (e) {
      // Exception Dart (SocketException, TimeoutException) — tăng đếm nhưng không hủy ngay
      final failCount = (prefs.getInt(_kFailCountKey) ?? 0) + 1;
      await prefs.setInt(_kFailCountKey, failCount);
      debugPrint('⚠️ [BG][Step4-Login] Exception #$failCount: $e');

      // Bug 8: catch block CŨNG kiểm tra ngưỡng — lưới an toàn dự phòng
      if (failCount >= _kMaxFails) {
        await BackgroundSyncService.cancelAll();
        await LocalNotificationService.showImmediate(
          id: 9998,
          title: 'Đồng bộ nền đã dừng',
          body: 'Không thể kết nối sau $failCount lần thử. Mở app để kiểm tra.',
        );
        await prefs.remove(_kFailCountKey);
      }
      return;
    }

    // 5. Xác định học kỳ hoạt động & Máy trạng thái nhận diện kỳ mới (State Machine)
    final now = DateTime.now();
    int currentNamHoc = prefs.getInt('active_nam_hoc') ?? (now.month >= 8 ? now.year : now.year - 1);
    int currentHocKy = prefs.getInt('active_hoc_ky') ?? (now.month >= 8 ? 1 : 2);
    bool isNewSemesterDetected = false;

    // Single Forward Pointer: Xác định kỳ mục tiêu theo ranh giới năm học
    // 01/07 - 30/11 -> Tìm HK1 năm học mới
    // 01/12 - 30/06 -> Tìm HK2
    final int targetHocKy;
    final int targetNamHoc;
    if (now.month >= 7 && now.month < 12) {
      targetHocKy = 1;
      targetNamHoc = now.year;
    } else {
      targetHocKy = 2;
      targetNamHoc = now.month == 12 ? now.year : now.year - 1;
    }

    final isSeekingNextSemester = (targetNamHoc > currentNamHoc) ||
        (targetNamHoc == currentNamHoc && targetHocKy > currentHocKy);

    if (isSeekingNextSemester) {
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastProbe = prefs.getString('last_semester_probe_date');
      // Thăm dò 1 lần/ngày vào ca chạy ban ngày
      if (lastProbe != todayStr) {
        await prefs.setString('last_semester_probe_date', todayStr);
        debugPrint('🔍 [BG][SemesterRollover] Đang thăm dò kỳ mới: HK$targetHocKy $targetNamHoc-${targetNamHoc + 1}...');
        final hasClasses = await ScheduleApi.probeSemesterHasSchedule(
          hocKy: targetHocKy,
          namHoc: targetNamHoc,
        );
        if (hasClasses) {
          debugPrint('🎉 [BG][SemesterRollover] Phát hiện lịch học kỳ mới: HK$targetHocKy $targetNamHoc-${targetNamHoc + 1}!');
          currentHocKy = targetHocKy;
          currentNamHoc = targetNamHoc;
          await prefs.setInt('active_hoc_ky', currentHocKy);
          await prefs.setInt('active_nam_hoc', currentNamHoc);
          isNewSemesterDetected = true;

          try {
            await LocalNotificationService.showImmediate(
              id: 999901,
              title: 'Thời khóa biểu học kỳ mới',
              body: 'Đã có lịch học HK$currentHocKy năm học $currentNamHoc-${currentNamHoc + 1} trên hệ thống tín chỉ!',
            );
          } catch (_) {}
        } else {
          debugPrint('⚪ [BG][SemesterRollover] HK$targetHocKy $targetNamHoc chưa có lịch mới, tiếp tục giữ kỳ hiện tại.');
        }
      }
    }

    final currentNamHocStr = '$currentNamHoc-${currentNamHoc + 1}';

    // Bug 5 Fix: Tính thêm kỳ liền trước để snapshot đồng bộ với fetchDiemRecentSemester
    final prevHocKy = currentHocKy == 1 ? 2 : 1;
    final prevNamHoc = currentHocKy == 1 ? currentNamHoc - 1 : currentNamHoc;
    final prevNamHocStr = '$prevNamHoc-${prevNamHoc + 1}';

    List<DiemMonHoc> prevDiem = [];
    List<LichHoc> prevLichHoc = [];
    List<LichThi> prevLichThi = [];
    List<Map<String, Object?>> prevFeeSummary = [];
    double prevDaDong = 0.0;

    try {
      // Bug 5 Fix: snapshot điểm của CẢ 2 KỲ (kỳ hiện tại + kỳ liền trước)
      final prevDiemCur = await GradeDb.getDiem(
          hocKy: currentHocKy, namHoc: currentNamHocStr, isOverview: false);
      final prevDiemOld = await GradeDb.getDiem(
          hocKy: prevHocKy, namHoc: prevNamHocStr, isOverview: false);
      prevDiem = [...prevDiemCur, ...prevDiemOld];
      prevLichHoc = await ScheduleDb.getLichHoc(
          hocKy: currentHocKy, namHoc: currentNamHocStr);
      prevLichThi = await ScheduleDb.getLichThi(
          hocKy: currentHocKy, namHoc: currentNamHocStr);
      prevFeeSummary = await FinanceDb.getAllFeeSummary();
      prevDaDong = prevFeeSummary.fold(
          0.0, (s, f) => s + ((f['da_nop'] as num?) ?? 0).toDouble());
    } catch (e) {
      debugPrint('⚠️ [BG][Step5-PrevSnapshot] Lỗi lấy snapshot dữ liệu cũ: $e');
    }

    // 6. Sync dữ liệu — Bug 2 & Bug 3: Checkpoint tuần tự theo thứ tự ưu tiên tuyệt đối
    // Thứ tự: Lịch thi (1) -> Điểm số (2) -> Lịch học (3 - TTL 7 ngày) -> Học phí (4 - TTL 7 ngày)
    const kBgTotalBudgetMs = 22000; // 22s — đủ dưới ngưỡng OS kill
    final budgetStart = DateTime.now().millisecondsSinceEpoch;

    bool budgetOk() =>
        DateTime.now().millisecondsSinceEpoch - budgetStart < kBgTotalBudgetMs;

    // Checkpoint 1: Lịch thi HK hiện tại (Ưu tiên 1 - Chạy mọi chu kỳ 6h)
    if (budgetOk()) {
      try {
        debugPrint(
            '🌐 [BG][CP1-Thi] Fetch lịch thi HK$currentHocKy $currentNamHocStr...');
        final r = await ScheduleApi.fetchLichThiWithStatus(
          hocKy: currentHocKy,
          namHoc: currentNamHoc,
        ).timeout(const Duration(seconds: 4));
        debugPrint(
            '📝 [BG][CP1-Thi] ${r.items.length} lịch thi, success=${r.success}');
        await ScheduleDb.saveLichThi(r.items, softDeleteAfter: r.success);
      } catch (e) {
        debugPrint('⚠️ [BG][CP1-Thi] Lỗi/timeout lịch thi: $e → giữ DB cũ');
      }
    } else {
      debugPrint('⚠️ [BG][CP1-Thi] Budget hết — bỏ qua lịch thi');
    }

    // Checkpoint 2: Điểm 2 kỳ gần nhất (Ưu tiên 2 - Chạy mọi chu kỳ 6h)
    if (budgetOk()) {
      try {
        debugPrint('🌐 [BG][CP2-Diem] Fetch điểm 2 kỳ gần nhất...');
        await GradeApi.fetchDiemRecentSemester(mssv: bgMssv)
            .timeout(const Duration(seconds: 6));
        debugPrint('📊 [BG][CP2-Diem] Fetch điểm hoàn tất');
      } catch (e) {
        debugPrint('⚠️ [BG][CP2-Diem] Lỗi/timeout điểm: $e → giữ DB cũ');
      }
    } else {
      debugPrint('⚠️ [BG][CP2-Diem] Budget hết — bỏ qua điểm');
    }

    // Checkpoint 3: Lịch học HK hiện tại (Ưu tiên 3 - Early-Stop & TTL 7 ngày)
    if (budgetOk()) {
      final isLichHocStale = await DatabaseService.isStale(
        'lich_hoc_hk${currentHocKy}_$currentNamHoc',
        const Duration(days: 7),
      );
      if (!isNewSemesterDetected && !isLichHocStale) {
        debugPrint(
            '📚 [BG][CP3-LichHoc] Lịch học còn hạn trong 7 ngày → bỏ qua fetch mạng (0s, 0 req)');
      } else {
        try {
          debugPrint(
              '🌐 [BG][CP3-LichHoc] Fetch lịch học HK$currentHocKy $currentNamHocStr (Early-Stop)...');
          final r = await ScheduleApi.fetchLichHocAllDotsWithStatus(
            hocKy: currentHocKy,
            namHoc: currentNamHoc,
            mssv: bgMssv,
          ).timeout(const Duration(seconds: 10));
          debugPrint(
              '📚 [BG][CP3-LichHoc] ${r.items.length} môn, complete=${r.complete}');
          await ScheduleDb.saveLichHoc(r.items, softDeleteAfter: r.complete);
          if (r.complete) {
            await DatabaseService.updateCacheMeta(
              'lich_hoc_hk${currentHocKy}_$currentNamHoc',
              'synced',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [BG][CP3-LichHoc] Lỗi/timeout lịch học: $e → giữ DB cũ');
        }
      }
    } else {
      debugPrint('⚠️ [BG][CP3-LichHoc] Budget hết — bỏ qua lịch học');
    }

    // Checkpoint 4: Học phí (Ưu tiên 4 - Cuối hàng chờ - TTL 7 ngày)
    if (budgetOk()) {
      final isFeeStale = await DatabaseService.isStale(
        'hoc_phi_all',
        const Duration(days: 7),
      );
      if (!isNewSemesterDetected && !isFeeStale) {
        debugPrint(
            '💰 [BG][CP4-HocPhi] Học phí còn hạn trong 7 ngày → bỏ qua fetch mạng (0s, 0 req)');
      } else {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch - budgetStart;
        final remaining = (kBgTotalBudgetMs - elapsed).clamp(3000, 8000);
        try {
          debugPrint(
              '🌐 [BG][CP4-HocPhi] Fetch học phí (budget còn ${remaining}ms)...');
          await FinanceApi.fetchAndSaveHocPhi()
              .timeout(Duration(milliseconds: remaining));
          debugPrint('💰 [BG][CP4-HocPhi] Fetch học phí hoàn tất');
          await DatabaseService.updateCacheMeta('hoc_phi_all', 'synced');
        } catch (e) {
          debugPrint('⚠️ [BG][CP4-HocPhi] Lỗi/timeout học phí: $e → giữ DB cũ');
        }
      }
    } else {
      debugPrint('⚠️ [BG][CP4-HocPhi] Budget hết — bỏ qua học phí');
    }

    // Đánh dấu thời gian sync thành công
    await prefs.setString(
        'bg_last_synced_at', DateTime.now().toIso8601String());

    // 7. Snapshot SAU sync (cùng scope HK hiện tại)
    List<DiemMonHoc> newDiem = [];
    List<LichHoc> newLichHoc = [];
    List<LichThi> newLichThi = [];
    List<Map<String, Object?>> newFeeSummary = [];
    double newDaDong = 0.0;

    try {
      // Bug 5 Fix: snapshot điểm sau sync của CẢ 2 KỲ
      final newDiemCur = await GradeDb.getDiem(
          hocKy: currentHocKy, namHoc: currentNamHocStr, isOverview: false);
      final newDiemOld = await GradeDb.getDiem(
          hocKy: prevHocKy, namHoc: prevNamHocStr, isOverview: false);
      newDiem = [...newDiemCur, ...newDiemOld];
      newLichHoc = await ScheduleDb.getLichHoc(
          hocKy: currentHocKy, namHoc: currentNamHocStr);
      newLichThi = await ScheduleDb.getLichThi(
          hocKy: currentHocKy, namHoc: currentNamHocStr);
      newFeeSummary = await FinanceDb.getAllFeeSummary();
      newDaDong = newFeeSummary.fold(
          0.0, (s, f) => s + ((f['da_nop'] as num?) ?? 0).toDouble());
    } catch (e) {
      debugPrint('⚠️ [BG][Step7-NewSnapshot] Lỗi lấy snapshot dữ liệu mới: $e');
    }

    // 8 & 9. Tạo thông báo nếu có thay đổi (B10: Set difference 2 chiều)
    try {
      final dismissed = await NotificationService.getDismissedIds();
      final allNotifs = await NotificationService.getAll();
      final nowTs = DateTime.now();

      Future<void> pushIfNew(String notifId, String title, String body, int tab,
          int localId) async {
        if (!dismissed.contains(notifId) &&
            !allNotifs.any((n) => n.id == notifId)) {
          await NotificationService.add(AppNotif(
              id: notifId,
              title: title,
              body: body,
              targetTab: tab,
              ts: nowTs));
          await LocalNotificationService.showImmediate(
              id: localId, title: title, body: body);
          debugPrint('⚙️ [BG][Notif] Pushed: $title');
        }
      }

      // ── Diff Điểm (Bug 5 Fix: Phương án b — đưa hash giá trị điểm vào key)
      String gradeFingerprint(DiemMonHoc d) {
        final courseKey = d.maMonHoc.isNotEmpty ? d.maMonHoc : d.tenMonHoc;
        return '$courseKey|${d.namHoc}|${d.hocKy}|${d.rawAvgGrade ?? ''}|${d.rawDiemSo ?? ''}|${d.rawExamScore ?? ''}|${d.rawComponentScore ?? ''}|${d.rawXepLoai ?? ''}|${d.canVote}';
      }

      bool hasAnyGrade(DiemMonHoc d) {
        return (d.rawDiemSo != null && d.rawDiemSo!.isNotEmpty) ||
            (d.rawAvgGrade != null && d.rawAvgGrade!.isNotEmpty) ||
            (d.rawExamScore != null && d.rawExamScore!.isNotEmpty) ||
            (d.rawComponentScore != null && d.rawComponentScore!.isNotEmpty) ||
            (d.diemTongKet != null) ||
            (d.avgGrade != null);
      }

      final prevMap = {
        for (final d in prevDiem)
          '${d.maMonHoc.isNotEmpty ? d.maMonHoc : d.tenMonHoc}_${d.namHoc}_${d.hocKy}':
              gradeFingerprint(d)
      };

      final updatedOrNewGradeCourses = <DiemMonHoc>[];
      for (final d in newDiem) {
        if (!hasAnyGrade(d)) continue; // Môn chưa có điểm không tính là điểm mới
        final courseKey =
            '${d.maMonHoc.isNotEmpty ? d.maMonHoc : d.tenMonHoc}_${d.namHoc}_${d.hocKy}';
        final prevFp = prevMap[courseKey];
        final newFp = gradeFingerprint(d);

        if (prevFp == null || prevFp != newFp) {
          // Môn mới có điểm, hoặc điểm được giảng viên nhập/sửa cập nhật
          updatedOrNewGradeCourses.add(d);
        }
      }

      if (prevDiem.isNotEmpty && updatedOrNewGradeCourses.isNotEmpty) {
        await pushIfNew(
          'notif_${bgMssv}_grade_${nowTs.millisecondsSinceEpoch}',
          'Có điểm mới 📊',
          'Vừa có ${updatedOrNewGradeCourses.length} môn học có điểm mới hoặc được cập nhật trên hệ thống.',
          2,
          2001,
        );
      }

      // ── Diff Lịch học (2 chiều)
      final diffLichHoc =
          ScheduleDiffCalculator.computeLichHocDiff(prevLichHoc, newLichHoc);
      if (prevLichHoc.isNotEmpty && diffLichHoc.added.isNotEmpty) {
        await pushIfNew(
          'notif_${bgMssv}_lich_add_${nowTs.millisecondsSinceEpoch}',
          'Lịch học được cập nhật 📅',
          'Vừa có ${diffLichHoc.added.length} buổi học mới được thêm vào lịch.',
          1,
          2002,
        );
      }
      if (prevLichHoc.isNotEmpty && diffLichHoc.removed.isNotEmpty) {
        await pushIfNew(
          'notif_${bgMssv}_lich_rem_${nowTs.millisecondsSinceEpoch}',
          'Lịch học được cập nhật 📅',
          'Có ${diffLichHoc.removed.length} buổi học đã được điều chỉnh hoặc hủy.',
          1,
          2005,
        );
      }

      // ── Diff Lịch thi (2 chiều)
      final diffLichThi =
          ScheduleDiffCalculator.computeLichThiDiff(prevLichThi, newLichThi);
      if (prevLichThi.isNotEmpty && diffLichThi.added.isNotEmpty) {
        await pushIfNew(
          'notif_${bgMssv}_thi_add_${nowTs.millisecondsSinceEpoch}',
          'Có lịch thi mới 📝',
          'Vừa có ${diffLichThi.added.length} lịch thi mới được cập nhật.',
          1,
          2003,
        );
      }
      if (prevLichThi.isNotEmpty && diffLichThi.removed.isNotEmpty) {
        await pushIfNew(
          'notif_${bgMssv}_thi_rem_${nowTs.millisecondsSinceEpoch}',
          'Lịch thi thay đổi 📝',
          'Có ${diffLichThi.removed.length} lịch thi đã được điều chỉnh hoặc hủy.',
          1,
          2006,
        );
      }

      // ── Diff Học phí
      if (prevDaDong > 0 && newDaDong > prevDaDong) {
        await pushIfNew(
          'notif_${bgMssv}_finance_${newDaDong.toInt()}',
          'Thanh toán được ghi nhận 💰',
          'Học phí đã được cập nhật trên hệ thống.',
          3,
          2004,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [BG][Step8-NotifDiff] Lỗi khi tạo thông báo: $e');
    }

    // 10. Lên lịch thông báo định kỳ (dùng bgMssv chuẩn xác)
    try {
      final isEnabled =
          await LocalNotificationService.isNotificationEnabled(bgMssv);
      if (isEnabled) {
        await LocalNotificationService.scheduleClasses(
            bgMssv, newLichHoc, newLichThi);
      } else {
        await LocalNotificationService.cancelAll();
      }
    } catch (e) {
      debugPrint(
          '⚠️ [BG][Step10-NotifSchedule] Lỗi khi lên lịch thông báo: $e');
    }

    debugPrint('⚙️ [BG] Sync hoàn tất thành công!');
  } catch (e) {
    debugPrint('❌ [BG] Lỗi không mong muốn trong task: $e');
  } finally {
    BackgroundSyncService._setSyncing(false);
    await SyncMutex.releaseLock(activeSyncMssv);
  }
}

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

// ──────────────────────────────────────────────────────────────
//  [DEBUG ONLY] Fault-inject variant: giả lập mất mạng giữa Future.wait
//  CHỈ gọi khi mssv=='admin' — đảm bảo bằng assert + guard trong caller
// ──────────────────────────────────────────────────────────────
Future<void> _runSyncLogicFaultInject({int delayMs = 300}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final mssv = prefs.getString('saved_mssv') ?? '';

  debugPrint(
      '⚡ [DEBUG-FaultInject] Bắt đầu sync với fault inject sau ${delayMs}ms...');

  if (BackgroundSyncService.isSyncing) {
    debugPrint(
        '⚙️ [BG] Task đã đang chạy ở isolate hiện tại, bỏ qua (Mutex active).');
    return;
  }

  final acquired = await SyncMutex.acquireLock(mssv);
  if (!acquired) {
    debugPrint(
        '⚙️ [BG] Persistent lock đang active ở isolate/process khác, bỏ qua lần gọi này.');
    return;
  }

  BackgroundSyncService._setSyncing(true);

  try {
    await LocalNotificationService.init();
    NotificationService.setMssv(mssv);
    await DatabaseService.setMssv(mssv);

    debugPrint(
        '🌐 [DEBUG-FaultInject][Step6] Bắt đầu Future.wait — sẽ inject SocketException sau ${delayMs}ms...');
    final fetchStart = DateTime.now();

    // Inject lỗi giả lập: sau delayMs, throw SocketException
    final faultFuture = Future.delayed(
      Duration(milliseconds: delayMs),
      () => throw const SocketException(
          'DEBUG: Simulated network failure mid-sync'),
    );

    // Chạy các API call thật (admin sẽ trả mock data ngay, không cần mạng)
    // nhưng faultFuture sẽ cancel toàn bộ Future.wait
    try {
      await Future.wait<dynamic>([
        ScheduleApi.fetchLichHocFromStartWithStatus(mssv: mssv),
        ScheduleApi.fetchLichThiFromStartWithStatus(mssv: mssv),
        FinanceApi.fetchAndSaveHocPhi(),
        faultFuture, // ← lỗi giả lập sẽ trigger ở đây
      ]).timeout(const Duration(seconds: 25));

      final fetchMs = DateTime.now().difference(fetchStart).inMilliseconds;
      debugPrint(
          '🌐 [DEBUG-FaultInject][Step6] Future.wait hoàn tất sau ${fetchMs}ms (unexpected — fault không trigger?)');
    } catch (e) {
      final fetchMs = DateTime.now().difference(fetchStart).inMilliseconds;
      debugPrint(
          '🌐 [DEBUG-FaultInject][Step6] Future.wait LỖI sau ${fetchMs}ms: $e');
      debugPrint(
          '✅ [DEBUG-FaultInject] Xác nhận: data cũ trong DB ĐƯỢC GIỮ NGUYÊN');
      debugPrint(
          '✅ [DEBUG-FaultInject] diff-delete CHƯA chạy (fetch bị abort trước khi ghi DB)');
      return; // Dừng tại đây — không ghi DB, không diff-delete
    }
  } catch (e) {
    debugPrint('❌ [DEBUG-FaultInject] Lỗi không mong muốn: $e');
  } finally {
    BackgroundSyncService._setSyncing(false);
    await SyncMutex.releaseLock(mssv);
    debugPrint('⚡ [DEBUG-FaultInject] Session kết thúc, mutex đã giải phóng.');
  }
}

// ──────────────────────────────────────────────────────────────
//  SyncMutex — Khóa atomic liên-isolate qua SharedPreferences reload
// ──────────────────────────────────────────────────────────────

class SyncMutex {
  static Future<File> _getLockFile(String mssv) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final sanitize = mssv.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final name = sanitize.isEmpty ? 'global' : sanitize;
    return File('${tempDir.path}/schedify_sync_$name.lock');
  }

  static Future<File> _getReclaimFile(String mssv) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final sanitize = mssv.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final name = sanitize.isEmpty ? 'global' : sanitize;
    return File('${tempDir.path}/schedify_sync_$name.reclaim');
  }

  static String? _activeOwnerToken;

  static Future<bool> acquireLock(String mssv,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final token =
        '${Isolate.current.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
    final lockUntil = DateTime.now().add(timeout).millisecondsSinceEpoch;
    final payload = '$token:$lockUntil';

    try {
      final file = await _getLockFile(mssv);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final parts = content.split(':');
          final existingUntil =
              parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          if (now < existingUntil) {
            return false; // Phím khóa đang hoạt động ở isolate/process khác
          }

          // Phục hồi stale lock an toàn qua atomic reclaim token
          final reclaimFile = await _getReclaimFile(mssv);
          try {
            await reclaimFile.create(exclusive: true);
          } catch (_) {
            return false; // Isolate khác đang đồng thời thu hồi stale lock
          }

          try {
            if (await file.exists()) {
              await file.delete();
            }
            await file.create(exclusive: true);
            await file.writeAsString(payload);
            _activeOwnerToken = token;
            return true;
          } finally {
            if (await reclaimFile.exists()) {
              await reclaimFile.delete();
            }
          }
        } catch (_) {
          return false;
        }
      }

      await file.create(exclusive: true);
      await file.writeAsString(payload);
      _activeOwnerToken = token;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> releaseLock(String mssv) async {
    try {
      final file = await _getLockFile(mssv);
      if (await file.exists()) {
        final content = await file.readAsString();
        final parts = content.split(':');
        final ownerToken = parts.first;

        // Chỉ xóa phím khóa nếu token trùng khớp với owner hiện tại (tránh xóa nhầm lock của isolate khác)
        if (_activeOwnerToken == null || ownerToken == _activeOwnerToken) {
          await file.delete();
        }
      }
    } catch (_) {
    } finally {
      _activeOwnerToken = null;
    }
  }
}

// ──────────────────────────────────────────────────────────────
//  BackgroundSyncService — API thống nhất cho cả 2 nền tảng
// ──────────────────────────────────────────────────────────────

class BackgroundSyncService {
  static bool _isSyncing = false;

  /// Flag kiểm tra task đồng bộ có đang chạy hay không (B4 Mutex)
  static bool get isSyncing => _isSyncing;

  static bool _isWorkmanagerInitialized = false;

  static void _setSyncing(bool value) {
    _isSyncing = value;
  }

  /// Khởi tạo nhẹ — gọi một lần sau runApp().
  static Future<void> initialize() async {
    try {
      if (Platform.isIOS) {
        // Đăng ký headless task handler cho trường hợp app bị kill trên iOS
        bf.BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
      }
    } catch (e) {
      debugPrint('❌ BackgroundSyncService Init Error: $e');
    }
  }

  /// Đảm bảo Workmanager Android được khởi tạo (chỉ gọi khi user đăng nhập/cần dùng)
  static Future<void> ensureWorkmanagerInitialized() async {
    if (Platform.isAndroid && !_isWorkmanagerInitialized) {
      try {
        await wm.Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: false,
        );
        _isWorkmanagerInitialized = true;
        debugPrint('✅ [Android BG] Workmanager initialized');
      } catch (e) {
        debugPrint('❌ BackgroundSyncService Workmanager Init Error: $e');
      }
    }
  }

  /// Đăng ký sync định kỳ sau khi đăng nhập.
  static Future<void> schedulePeriodicSync({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mssv = prefs.getString('saved_mssv') ?? '';
      final key = 'bg_sync_scheduled_$mssv';

      if (!force && prefs.getBool(key) == true) {
        debugPrint(
            'ℹ️ [BG] Periodic sync đã được đăng ký trước đó, bỏ qua re-init Workmanager');
        return;
      }

      if (Platform.isAndroid) {
        await ensureWorkmanagerInitialized();
        await wm.Workmanager().registerPeriodicTask(
          kBgSyncTaskUniqueName,
          kBgSyncTaskName,
          frequency: const Duration(hours: 6),
          constraints: wm.Constraints(
            networkType: wm.NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
          existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.keep,
          backoffPolicy: wm.BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(minutes: 30),
        );
        await prefs.setBool(key, true);
        debugPrint('✅ [Android BG] Đã đăng ký periodic sync (mỗi 6 tiếng)');
      } else if (Platform.isIOS) {
        await bf.BackgroundFetch.configure(
          bf.BackgroundFetchConfig(
            minimumFetchInterval: 360, // phút (6 tiếng = 360 phút)
            stopOnTerminate: false, // tiếp tục chạy kể cả khi app bị kill
            enableHeadless: true, // bắt buộc để headless task hoạt động
            startOnBoot: true,
            requiredNetworkType: bf.NetworkType.ANY,
            requiresBatteryNotLow: true,
          ),
          // Callback khi app đang foreground/background
          (taskId) async {
            debugPrint('⚙️ [iOS BG] Fetch event: $taskId');
            await _runSyncLogic();
            bf.BackgroundFetch.finish(taskId);
          },
          // Callback timeout
          (taskId) async {
            debugPrint('⚙️ [iOS BG] TIMEOUT: $taskId');
            bf.BackgroundFetch.finish(taskId);
          },
        );
        await prefs.setBool(key, true);
        debugPrint('✅ [iOS BG] Đã cấu hình background_fetch (mỗi 6 tiếng)');
      }
    } catch (e) {
      debugPrint('❌ schedulePeriodicSync error: $e');
    }
  }

  /// Kiểm tra xem BG task có bị deferment lâu quá không (B8)
  static Future<void> checkSyncHealth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAttempt = prefs.getString('bg_last_attempted_at');
      final lastSync = prefs.getString('bg_last_synced_at');

      if (lastAttempt != null && lastSync != null) {
        final attemptDt = DateTime.tryParse(lastAttempt);
        final syncDt = DateTime.tryParse(lastSync);

        if (attemptDt != null && syncDt != null) {
          final diff = attemptDt.difference(syncDt);
          if (diff.inHours >= 12) {
            debugPrint(
                '⚠️ [BG Health] Cảnh báo: Task đã cố chạy lúc $lastAttempt nhưng sync thành công gần nhất là $lastSync (chênh lệch ${diff.inHours}h - có thể bị hệ thống/pin hoãn)');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [BG Health] Check error: $e');
    }
  }

  /// Hủy background task — gọi khi đăng xuất.
  static Future<void> cancelAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mssv = prefs.getString('saved_mssv') ?? '';
      if (mssv.isNotEmpty) {
        await prefs.remove('bg_sync_scheduled_$mssv');
      }
      if (Platform.isAndroid) {
        await ensureWorkmanagerInitialized();
        await wm.Workmanager().cancelAll();
        debugPrint('🛑 [Android BG] Đã hủy tất cả background task');
      } else if (Platform.isIOS) {
        await bf.BackgroundFetch.stop();
        debugPrint('🛑 [iOS BG] Đã dừng background_fetch');
      }
    } catch (e) {
      debugPrint('❌ cancelAll error: $e');
    }
  }

  /// Chạy thử ngay lập tức — dùng để debug.
  static Future<void> runOnce() async {
    if (Platform.isAndroid) {
      await ensureWorkmanagerInitialized();
      await wm.Workmanager().registerOneOffTask(
        '${kBgSyncTaskUniqueName}_once',
        kBgSyncTaskName,
        constraints: wm.Constraints(networkType: wm.NetworkType.connected),
      );
    } else if (Platform.isIOS) {
      await bf.BackgroundFetch.scheduleTask(bf.TaskConfig(
        taskId: kBgFetchTaskId,
        delay: 0,
        periodic: false,
        requiresNetworkConnectivity: true,
      ));
    }
    debugPrint('🚀 [BG] One-off sync đã được đăng ký');
  }

  /// [DEBUG ONLY] Việc 3: Trigger sync + inject lỗi giả lập mất mạng sau delay ngắn.
  /// Cơ chế: set flag _debugFaultInjectActive = true TRƯỚC khi sync chạy.
  /// ScheduleApi và GradeApi sẽ kiểm tra flag này và throw SocketException giả lập.
  /// CHỈ hoạt động khi mssv == 'admin' và kDebugMode == true.
  static Future<void> runOnceFaultInject({int delayMs = 300}) async {
    assert(() {
      debugPrint('⚠️ [DEBUG] runOnceFaultInject chỉ dùng trong debug mode');
      return true;
    }());
    final prefs = await SharedPreferences.getInstance();
    final mssv = prefs.getString('saved_mssv') ?? '';
    if (mssv != 'admin') {
      debugPrint('🚫 [DEBUG] runOnceFaultInject bị chặn: mssv=$mssv ≠ admin');
      return;
    }
    // Set flag fault inject vào SharedPreferences (đọc bởi _runSyncLogic trong isolate)
    await prefs.setBool('debug_fault_inject', true);
    await prefs.setInt('debug_fault_inject_delay_ms', delayMs);
    debugPrint(
        '⚡ [DEBUG] Fault inject đã bật (delay=${delayMs}ms), đăng ký one-off task...');
    // Gọi _runSyncLogic trực tiếp trong foreground (không qua WorkManager) để dễ capture log
    await _runSyncLogicFaultInject(delayMs: delayMs);
    await prefs.setBool('debug_fault_inject', false);
    debugPrint('✅ [DEBUG] Fault inject session kết thúc, flag đã reset');
  }

  /// [DEBUG ONLY] Việc 4: Trigger 2 lần sync gần như đồng thời để test mutex.
  static Future<void> runOnceConcurrent() async {
    assert(() {
      debugPrint('⚠️ [DEBUG] runOnceConcurrent chỉ dùng trong debug mode');
      return true;
    }());
    final prefs = await SharedPreferences.getInstance();
    final mssv = prefs.getString('saved_mssv') ?? '';
    if (mssv != 'admin') {
      debugPrint('🚫 [DEBUG] runOnceConcurrent bị chặn: mssv=$mssv ≠ admin');
      return;
    }
    debugPrint(
        '⚡ [DEBUG][MutexTest] Firing 2 _runSyncLogic() concurrently (<300ms gap)...');
    // Chạy 2 lần song song: 1 lần ngay, 1 lần sau 200ms
    final f1 = _runSyncLogic();
    await Future.delayed(const Duration(milliseconds: 200));
    final f2 = _runSyncLogic();
    await Future.wait([f1, f2]);
    debugPrint('⚡ [DEBUG][MutexTest] Cả 2 lần gọi đã kết thúc.');
  }
}

class ScheduleDiffResult {
  final Set<String> added;
  final Set<String> removed;

  ScheduleDiffResult({required this.added, required this.removed});
}

class ScheduleDiffCalculator {
  static String getLichHocKey(LichHoc l) {
    return '${l.tenHocPhan}_${l.thu}_${l.tiet}_${l.thoiGian}_${l.hocKy}_${l.namHoc}_${l.dotHoc}';
  }

  static String getLichThiKey(LichThi l) {
    return '${l.maMonHoc}_${l.tenMonHoc}_${l.ngayThi}_${l.caThi}_${l.hocKy}_${l.namHoc}';
  }

  static ScheduleDiffResult computeLichHocDiff(
      List<LichHoc> prev, List<LichHoc> next) {
    final prevKeys = prev.map(getLichHocKey).toSet();
    final nextKeys = next.map(getLichHocKey).toSet();
    return ScheduleDiffResult(
      added: nextKeys.difference(prevKeys),
      removed: prevKeys.difference(nextKeys),
    );
  }

  static ScheduleDiffResult computeLichThiDiff(
      List<LichThi> prev, List<LichThi> next) {
    final prevKeys = prev.map(getLichThiKey).toSet();
    final nextKeys = next.map(getLichThiKey).toSet();
    return ScheduleDiffResult(
      added: nextKeys.difference(prevKeys),
      removed: prevKeys.difference(nextKeys),
    );
  }
}
