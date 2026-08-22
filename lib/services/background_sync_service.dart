import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'package:background_fetch/background_fetch.dart' as bf;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'hau_api_service.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';
import 'database_service.dart';
import 'db/schedule_db.dart';
import 'db/grade_db.dart';
import 'db/finance_db.dart';
import 'api/grade_api.dart';
import 'api/schedule_api.dart';
import 'api/finance_api.dart';
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
  final mssv = prefs.getString('saved_mssv') ?? '';

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
  debugPrint('⚙️ [BG] Task bắt đầu chạy...');

  try {
    // Ghi lại thời gian nỗ lực thực thi (B8 - theo dõi deferment)
    await prefs.setString(
        'bg_last_attempted_at', DateTime.now().toIso8601String());

    // 1. Đọc thông tin đăng nhập đã lưu
    final mssv = prefs.getString('saved_mssv') ?? '';
    final pw = prefs.getString('saved_pw') ?? '';

    if (mssv.isEmpty || (mssv != 'admin' && pw.isEmpty)) {
      debugPrint(
          '⚙️ [BG][Step1-Credentials] Bỏ qua: thiếu thông tin đăng nhập (MSSV/PW)');
      return;
    }

    // 2. Khởi tạo service
    try {
      await LocalNotificationService.init();
      NotificationService.setMssv(mssv);
      await DatabaseService.setMssv(mssv);
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

    // 4. Login lấy session mới
    try {
      final loginError = await HauApiService.login(mssv, pw);
      if (loginError != null) {
        debugPrint('⚙️ [BG][Step4-Login] Login thất bại: $loginError');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [BG][Step4-Login] Ngoại lệ khi đăng nhập: $e');
      return;
    }

    // 5. Snapshot TRƯỚC sync
    List<DiemMonHoc> prevDiem = [];
    List<LichHoc> prevLichHoc = [];
    List<LichThi> prevLichThi = [];
    List<Map<String, Object?>> prevFeeSummary = [];
    double prevDaDong = 0.0;

    try {
      prevDiem = await GradeDb.getDiem();
      prevLichHoc = await ScheduleDb.getLichHoc();
      prevLichThi = await ScheduleDb.getLichThi();
      prevFeeSummary = await FinanceDb.getAllFeeSummary();
      prevDaDong = prevFeeSummary.fold(
          0.0, (s, f) => s + ((f['da_nop'] as num?) ?? 0).toDouble());
    } catch (e) {
      debugPrint('⚠️ [BG][Step5-PrevSnapshot] Lỗi lấy snapshot dữ liệu cũ: $e');
    }

    // 6. Sync dữ liệu — fetch & save
    List<DiemMonHoc> fetchedDiem = [];
    LichHocScanResult fetchedLichHocResult =
        (items: <LichHoc>[], complete: false);
    LichThiScanResult fetchedLichThiResult =
        (items: <LichThi>[], complete: false);

    try {
      // Việc 1: Log TRƯỚC khi gọi Future.wait — để canh thời điểm tắt mạng
      final fetchStart = DateTime.now();
      debugPrint('🌐 [BG][Step6] Bắt đầu gọi 4 API song song lúc ${fetchStart.toIso8601String()}...');

      final results = await Future.wait<dynamic>([
        GradeApi.fetchDiem(),
        ScheduleApi.fetchLichHocFromStartWithStatus(mssv: mssv),
        ScheduleApi.fetchLichThiFromStartWithStatus(mssv: mssv),
        FinanceApi.fetchAndSaveHocPhi(),
      ]).timeout(const Duration(seconds: 25));

      final fetchMs = DateTime.now().difference(fetchStart).inMilliseconds;
      debugPrint('🌐 [BG][Step6] Future.wait hoàn tất sau ${fetchMs}ms');

      fetchedDiem = List<DiemMonHoc>.from(results[0] as List);
      fetchedLichHocResult = results[1] as LichHocScanResult;
      fetchedLichThiResult = results[2] as LichThiScanResult;

      // Log rõ kết quả fetch để không bao giờ bị "im lặng bỏ qua"
      debugPrint('📊 [BG][Step6-Grade] fetchDiem() → ${fetchedDiem.length} môn'
          '${fetchedDiem.isEmpty ? " ⚠️ (rỗng — admin mock chỉ trả data qua fetchDiemAllKyWithSummary, không qua fetchDiem)" : ""}');
      debugPrint('📚 [BG][Step6-LichHoc] ${fetchedLichHocResult.items.length} môn'
          ' complete=${fetchedLichHocResult.complete}');
      debugPrint('📚 [BG][Step6-LichThi] ${fetchedLichThiResult.items.length} lịch thi'
          ' complete=${fetchedLichThiResult.complete}');
    } catch (e) {
      // Việc 1: Log SAU khi Future.wait throw
      debugPrint('🌐 [BG][Step6] Future.wait lỗi/timeout: $e');
      debugPrint('⚠️ [BG][Step6-FetchAndSave] Sync network/timeout error: $e → data cũ trong DB được GIỮ NGUYÊN (chưa diff-delete)');
    }

    // Ghi dữ liệu Điểm vào DB
    if (fetchedDiem.isNotEmpty) {
      try {
        await GradeDb.saveDiem(
          fetchedDiem.map((d) => d.toMap()).toList(),
          mssv: mssv,
        );
        debugPrint('💾 [BG][Step6-SaveDiem] Đã ghi ${fetchedDiem.length} môn vào DB');
      } catch (e) {
        debugPrint('⚠️ [BG][Step6-SaveDiem] Lỗi ghi điểm: $e');
      }
    } else {
      debugPrint('⚠️ [BG][Step6-SaveDiem] fetchedDiem rỗng → bỏ qua ghi DB.'
          ' NOTE: admin mock data điểm KHÔNG được sync qua GradeApi.fetchDiem().'
          ' Đây là hành vi chủ đích của demo mode (dữ liệu điểm admin chỉ được seed 1 lần vào DB).');
    }


    // Ghi Lịch học vào DB nếu complete == true (B1+B7 diff-delete logic)
    if (fetchedLichHocResult.complete &&
        fetchedLichHocResult.items.isNotEmpty) {
      try {
        await ScheduleDb.saveLichHoc(fetchedLichHocResult.items);
      } catch (e) {
        debugPrint('⚠️ [BG][Step6-SaveLichHoc] Lỗi ghi lịch học: $e');
      }
    } else if (!fetchedLichHocResult.complete) {
      debugPrint(
          '⚠️ [BG][Step6-SaveLichHoc] LichHoc fetch không hoàn tất (complete=false) → giữ nguyên data cũ');
    }

    // Ghi Lịch thi vào DB nếu complete == true
    if (fetchedLichThiResult.complete &&
        fetchedLichThiResult.items.isNotEmpty) {
      try {
        await ScheduleDb.saveLichThi(fetchedLichThiResult.items);
      } catch (e) {
        debugPrint('⚠️ [BG][Step6-SaveLichThi] Lỗi ghi lịch thi: $e');
      }
    } else if (!fetchedLichThiResult.complete) {
      debugPrint(
          '⚠️ [BG][Step6-SaveLichThi] LichThi fetch không hoàn tất (complete=false) → giữ nguyên data cũ');
    }

    // Đánh dấu thời gian sync thành công
    await prefs.setString(
        'bg_last_synced_at', DateTime.now().toIso8601String());

    // 7. Snapshot SAU sync
    List<DiemMonHoc> newDiem = [];
    List<LichHoc> newLichHoc = [];
    List<LichThi> newLichThi = [];
    List<Map<String, Object?>> newFeeSummary = [];
    double newDaDong = 0.0;

    try {
      newDiem = await GradeDb.getDiem();
      newLichHoc = await ScheduleDb.getLichHoc();
      newLichThi = await ScheduleDb.getLichThi();
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
      final now = DateTime.now();

      Future<void> pushIfNew(String notifId, String title, String body, int tab,
          int localId) async {
        if (!dismissed.contains(notifId) &&
            !allNotifs.any((n) => n.id == notifId)) {
          await NotificationService.add(AppNotif(
              id: notifId, title: title, body: body, targetTab: tab, ts: now));
          await LocalNotificationService.showImmediate(
              id: localId, title: title, body: body);
          debugPrint('⚙️ [BG][Notif] Pushed: $title');
        }
      }

      // ── Diff Điểm
      final prevDiemKeys = prevDiem
          .map((d) =>
              '${d.maMonHoc.isNotEmpty ? d.maMonHoc : d.tenMonHoc}_${d.namHoc}_${d.hocKy}')
          .toSet();
      final newDiemKeys = newDiem
          .map((d) =>
              '${d.maMonHoc.isNotEmpty ? d.maMonHoc : d.tenMonHoc}_${d.namHoc}_${d.hocKy}')
          .toSet();
      final addedDiem = newDiemKeys.difference(prevDiemKeys);

      if (prevDiem.isNotEmpty && addedDiem.isNotEmpty) {
        await pushIfNew(
          'notif_${mssv}_grade_${now.millisecondsSinceEpoch}',
          'Có điểm mới 📊',
          'Vừa có ${addedDiem.length} môn học có điểm mới trên hệ thống.',
          2,
          2001,
        );
      }

      // ── Diff Lịch học (B10: 2 chiều)
      final diffLichHoc =
          ScheduleDiffCalculator.computeLichHocDiff(prevLichHoc, newLichHoc);
      final addedLichHoc = diffLichHoc.added;
      final removedLichHoc = diffLichHoc.removed;

      if (prevLichHoc.isNotEmpty && addedLichHoc.isNotEmpty) {
        await pushIfNew(
          'notif_${mssv}_lich_add_${now.millisecondsSinceEpoch}',
          'Lịch học được cập nhật 📅',
          'Vừa có ${addedLichHoc.length} buổi học mới được thêm vào lịch.',
          1,
          2002,
        );
      }
      if (prevLichHoc.isNotEmpty && removedLichHoc.isNotEmpty) {
        await pushIfNew(
          'notif_${mssv}_lich_rem_${now.millisecondsSinceEpoch}',
          'Lịch học được cập nhật 📅',
          'Có ${removedLichHoc.length} buổi học đã được điều chỉnh hoặc hủy.',
          1,
          2005,
        );
      }

      // ── Diff Lịch thi (B10: 2 chiều)
      final diffLichThi =
          ScheduleDiffCalculator.computeLichThiDiff(prevLichThi, newLichThi);
      final addedLichThi = diffLichThi.added;
      final removedLichThi = diffLichThi.removed;

      if (prevLichThi.isNotEmpty && addedLichThi.isNotEmpty) {
        await pushIfNew(
          'notif_${mssv}_thi_add_${now.millisecondsSinceEpoch}',
          'Có lịch thi mới 📝',
          'Vừa có ${addedLichThi.length} lịch thi mới được cập nhật.',
          1,
          2003,
        );
      }
      if (prevLichThi.isNotEmpty && removedLichThi.isNotEmpty) {
        await pushIfNew(
          'notif_${mssv}_thi_rem_${now.millisecondsSinceEpoch}',
          'Lịch thi thay đổi 📝',
          'Có ${removedLichThi.length} lịch thi đã được điều chỉnh hoặc hủy.',
          1,
          2006,
        );
      }

      // ── Diff Học phí
      if (prevDaDong > 0 && newDaDong > prevDaDong) {
        await pushIfNew(
          'notif_${mssv}_finance_${newDaDong.toInt()}',
          'Thanh toán được ghi nhận 💰',
          'Học phí đã được cập nhật trên hệ thống.',
          3,
          2004,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [BG][Step8-NotifDiff] Lỗi khi tạo thông báo: $e');
    }

    // 10. Lên lịch thông báo định kỳ (Bọc try-catch riêng để lỗi không làm sập BG task)
    try {
      final isEnabled =
          await LocalNotificationService.isNotificationEnabled(mssv);
      if (isEnabled) {
        debugPrint(
            '⚙️ [BG][Step10-NotifSchedule] Đang lên lịch thông báo nhắc nhở...');
        await LocalNotificationService.scheduleClasses(
            mssv, newLichHoc, newLichThi);
      } else {
        debugPrint(
            '⚙️ [BG][Step10-NotifSchedule] Thông báo đang tắt, hủy các lịch cũ');
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
    final prefs = await SharedPreferences.getInstance();
    final mssv = prefs.getString('saved_mssv') ?? '';
    await SyncMutex.releaseLock(mssv);
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

  debugPrint('⚡ [DEBUG-FaultInject] Bắt đầu sync với fault inject sau ${delayMs}ms...');

  if (BackgroundSyncService.isSyncing) {
    debugPrint('⚙️ [BG] Task đã đang chạy ở isolate hiện tại, bỏ qua (Mutex active).');
    return;
  }

  final acquired = await SyncMutex.acquireLock(mssv);
  if (!acquired) {
    debugPrint('⚙️ [BG] Persistent lock đang active ở isolate/process khác, bỏ qua lần gọi này.');
    return;
  }

  BackgroundSyncService._setSyncing(true);

  try {
    await LocalNotificationService.init();
    NotificationService.setMssv(mssv);
    await DatabaseService.setMssv(mssv);

    debugPrint('🌐 [DEBUG-FaultInject][Step6] Bắt đầu Future.wait — sẽ inject SocketException sau ${delayMs}ms...');
    final fetchStart = DateTime.now();

    // Inject lỗi giả lập: sau delayMs, throw SocketException
    final faultFuture = Future.delayed(
      Duration(milliseconds: delayMs),
      () => throw const SocketException('DEBUG: Simulated network failure mid-sync'),
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
      debugPrint('🌐 [DEBUG-FaultInject][Step6] Future.wait hoàn tất sau ${fetchMs}ms (unexpected — fault không trigger?)');
    } catch (e) {
      final fetchMs = DateTime.now().difference(fetchStart).inMilliseconds;
      debugPrint('🌐 [DEBUG-FaultInject][Step6] Future.wait LỖI sau ${fetchMs}ms: $e');
      debugPrint('✅ [DEBUG-FaultInject] Xác nhận: data cũ trong DB ĐƯỢC GIỮ NGUYÊN');
      debugPrint('✅ [DEBUG-FaultInject] diff-delete CHƯA chạy (fetch bị abort trước khi ghi DB)');
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
      {Duration timeout = const Duration(seconds: 45)}) async {
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

  static void _setSyncing(bool value) {
    _isSyncing = value;
  }

  /// Khởi tạo — gọi một lần trong main().
  static Future<void> initialize() async {
    try {
      if (Platform.isAndroid) {
        await wm.Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: false,
        );
      } else if (Platform.isIOS) {
        // Đăng ký headless task handler cho trường hợp app bị kill
        bf.BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
      }
    } catch (e) {
      debugPrint('❌ BackgroundSyncService Init Error: $e');
    }
  }

  /// Đăng ký sync định kỳ sau khi đăng nhập.
  static Future<void> schedulePeriodicSync() async {
    if (Platform.isAndroid) {
      await wm.Workmanager().registerPeriodicTask(
        kBgSyncTaskUniqueName,
        kBgSyncTaskName,
        frequency: const Duration(hours: 6),
        constraints: wm.Constraints(
          networkType: wm.NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: wm.BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 30),
      );
      debugPrint('✅ [Android BG] Đã đăng ký periodic sync (mỗi 6 tiếng)');
    } else if (Platform.isIOS) {
      // B9 Note: Giữ cả cấu hình constraint iOS (`requiredNetworkType: NetworkType.ANY`)
      // và kiểm tra thủ công `_checkNetwork()` trong `_runSyncLogic()` nhằm đảm bảo tính tương thích
      // giữa cơ chế lập lịch của iOS BackgroundFetch và kiểm tra HTTP động trước khi gọi API.
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
      debugPrint('✅ [iOS BG] Đã cấu hình background_fetch (mỗi 6 tiếng)');
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
    debugPrint('⚡ [DEBUG] Fault inject đã bật (delay=${delayMs}ms), đăng ký one-off task...');
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
    debugPrint('⚡ [DEBUG][MutexTest] Firing 2 _runSyncLogic() concurrently (<300ms gap)...');
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
