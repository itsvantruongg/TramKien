import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'package:background_fetch/background_fetch.dart' as bf;
import 'package:http/http.dart' as http;

import 'hau_api_service.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';
import 'database_service.dart';
import 'api/grade_api.dart';
import 'api/schedule_api.dart';
import '../models/models.dart';

/// Tên task
const kBgSyncTaskName = 'tramkien_bg_sync';
const kBgSyncTaskUniqueName = 'tramkien_periodic_sync';
const kBgFetchTaskId = 'com.tramkien.bgsync';

// ──────────────────────────────────────────────────────────────
//  ANDROID: Workmanager entry-point (top-level, @pragma required)
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  wm.Workmanager().executeTask((taskName, inputData) async {
    debugPrint('⚙️ [Android BG] Task: $taskName');
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
  debugPrint('⚙️ [BG] Task bắt đầu chạy...');
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Đọc thông tin đăng nhập đã lưu
    final prefs = await SharedPreferences.getInstance();
    final mssv = prefs.getString('saved_mssv') ?? '';
    final pw = prefs.getString('saved_pw') ?? '';
    final remember = prefs.getBool('remember_login') ?? false;

    // Nếu không nhớ mật khẩu, chúng ta chỉ cho phép sync nếu MSSV hiện tại đang trùng với mssv trong prefs
    // (Điều này đảm bảo khi app đang mở vẫn sync được, nhưng khi app đóng thì phải có mật khẩu lưu mới login được)
    if (mssv.isEmpty || (mssv != 'admin' && pw.isEmpty)) {
      debugPrint('⚙️ [BG] Bỏ qua: thiếu thông tin đăng nhập (MSSV/PW)');
      return;
    }

    // 2. Khởi tạo service
    await LocalNotificationService.init();
    NotificationService.setMssv(mssv);
    await DatabaseService.setMssv(mssv);

    // 3. Kiểm tra mạng
    if (!await _checkNetwork()) {
      debugPrint('⚙️ [BG] Offline – bỏ qua sync');
      return;
    }

    // 4. Login lấy session mới
    final loginError = await HauApiService.login(mssv, pw);
    if (loginError != null) {
      debugPrint('⚙️ [BG] Login thất bại: $loginError');
      return;
    }

    // 5. Snapshot TRƯỚC sync
    final prevDiem = await GradeDb.getDiem();
    final prevLichHoc = await ScheduleDb.getLichHoc();
    final prevLichThi = await ScheduleDb.getLichThi();

    // 6. Sync dữ liệu
    try {
      await Future.wait([
        GradeApi.fetchDiem(),
        ScheduleApi.fetchLichHocFromStart(mssv: mssv),
        ScheduleApi.fetchLichThiFromStart(mssv: mssv),
      ]);
    } catch (e) {
      debugPrint('⚙️ [BG] Sync error: $e');
    }

    // 7. Snapshot SAU sync
    final newDiem = await GradeDb.getDiem();
    final newLichHoc = await ScheduleDb.getLichHoc();
    final newLichThi = await ScheduleDb.getLichThi();

    // 8. Đọc dismissed list một lần
    final dismissed = await NotificationService.getDismissedIds();
    final allNotifs = await NotificationService.getAll();
    final now = DateTime.now();

    // 9. Tạo thông báo nếu có thay đổi
    Future<void> pushIfNew(
        String notifId, String title, String body, int tab, int localId) async {
      if (!dismissed.contains(notifId) &&
          !allNotifs.any((n) => n.id == notifId)) {
        await NotificationService.add(AppNotif(
            id: notifId, title: title, body: body, targetTab: tab, ts: now));
        await LocalNotificationService.showImmediate(
            id: localId, title: title, body: body);
        debugPrint('⚙️ [BG] Pushed: $title');
      }
    }

    if (prevDiem.isNotEmpty && newDiem.length > prevDiem.length) {
      final diff = newDiem.length - prevDiem.length;
      await pushIfNew(
        'grade_to_${newDiem.length}',
        'Có điểm mới 📊',
        'Vừa có $diff môn học có điểm mới trên hệ thống.',
        2,
        2001,
      );
    }

    if (prevLichHoc.isNotEmpty && newLichHoc.length > prevLichHoc.length) {
      await pushIfNew(
        'lich_to_${newLichHoc.length}',
        'Lịch học được cập nhật 📅',
        'Có ${newLichHoc.length - prevLichHoc.length} buổi học mới.',
        1,
        2002,
      );
    }

    if (prevLichThi.isNotEmpty && newLichThi.length > prevLichThi.length) {
      await pushIfNew(
        'thi_to_${newLichThi.length}',
        'Có lịch thi mới 📝',
        '${newLichThi.length - prevLichThi.length} lịch thi vừa được cập nhật.',
        1,
        2003,
      );
    }

    // 10. Lên lịch thông báo định kỳ (Chỉ nếu đã bật)
    final isEnabled = await LocalNotificationService.isNotificationEnabled(mssv);
    if (isEnabled) {
      debugPrint('⚙️ [BG] Đang lên lịch thông báo nhắc nhở...');
      await LocalNotificationService.scheduleClasses(
          mssv, newLichHoc, newLichThi);
    } else {
      debugPrint('⚙️ [BG] Thông báo đang tắt, hủy các lịch cũ');
      await LocalNotificationService.cancelAll();
    }

    debugPrint('⚙️ [BG] Sync hoàn tất');
  } catch (e) {
    debugPrint('⚙️ [BG] Lỗi: $e');
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
//  BackgroundSyncService — API thống nhất cho cả 2 nền tảng
// ──────────────────────────────────────────────────────────────

class BackgroundSyncService {
  /// Khởi tạo — gọi một lần trong main().
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await wm.Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
    } else if (Platform.isIOS) {
      // Đăng ký headless task handler cho trường hợp app bị kill
      bf.BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
    }
  }

  /// Đăng ký sync định kỳ sau khi đăng nhập.
  static Future<void> schedulePeriodicSync() async {
    if (Platform.isAndroid) {
      await wm.Workmanager().registerPeriodicTask(
        kBgSyncTaskUniqueName,
        kBgSyncTaskName,
        frequency: const Duration(hours: 2),
        constraints: wm.Constraints(
          networkType: wm.NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: wm.BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
      debugPrint('✅ [Android BG] Đã đăng ký periodic sync (mỗi 2 tiếng)');
    } else if (Platform.isIOS) {
      // iOS: dùng background_fetch
      await bf.BackgroundFetch.configure(
        bf.BackgroundFetchConfig(
          minimumFetchInterval: 120, // phút (2 tiếng)
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
      debugPrint('✅ [iOS BG] Đã cấu hình background_fetch (mỗi 2 tiếng)');
    }
  }

  /// Hủy background task — gọi khi đăng xuất.
  static Future<void> cancelAll() async {
    if (Platform.isAndroid) {
      await wm.Workmanager().cancelAll();
      debugPrint('🛑 [Android BG] Đã hủy tất cả background task');
    } else if (Platform.isIOS) {
      await bf.BackgroundFetch.stop();
      debugPrint('🛑 [iOS BG] Đã dừng background_fetch');
    }
  }

  /// Chạy thử ngay lập tức — dùng để debug.
  static Future<void> runOnce() async {
    if (Platform.isAndroid) {
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
}
