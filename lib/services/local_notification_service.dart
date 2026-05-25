import 'dart:io';
//import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:android_intent_plus/android_intent_plus.dart';
// import 'package:android_intent_plus/flag.dart';
import '../models/models.dart';
import 'notification_service.dart';

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
    void Function(NotificationResponse)?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );
    _initialized = true;
  }

  static Future<void> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<bool> isNotificationEnabled(String mssv) async {
    if (mssv.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('enable_schedule_notif_$mssv') ?? false;
  }

  static Future<void> setNotificationEnabled(String mssv, bool enabled) async {
    if (mssv.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_schedule_notif_$mssv', enabled);
    if (!enabled) {
      await cancelAll();
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      print('Đã hủy toàn bộ thông báo.');
    } catch (e) {
      print('Lỗi khi cancelAll: $e');
    }
  }

  static Future<void> showImmediate(
      {required int id, required String title, required String body}) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'update_channel',
            'Thông báo cập nhật',
            channelDescription: 'Thông báo khi có điểm, lịch mới',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Lỗi khi showImmediate: $e');
    }
  }

  static Future<void> showTestNotification() async {
    try {
      await _plugin.show(
        9999,
        'Thử nghiệm thông báo',
        'Nếu bạn nhận được tin nhắn này, ứng dụng đã được cấp quyền thông báo thành công!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel_v2',
            'Kiểm tra thông báo',
            channelDescription: 'Kênh để kiểm tra thông báo',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      print('Đã gửi thông báo thử nghiệm.');
    } catch (e) {
      print('Lỗi khi showTestNotification: $e');
    }
  }

  static bool _lichHocMatchesDate(LichHoc l, DateTime date) {
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

  static DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> scheduleClasses(
      String mssv, List<LichHoc> lichHoc, List<LichThi> lichThi) async {
    if (mssv.isEmpty) return;
    if (!await isNotificationEnabled(mssv)) {
      await cancelAll();
      return;
    }

    // Thay vì cancelAll() xóa nhầm cả thông báo test (ID 9999),
    // ta chỉ xóa các ID từ 1 đến 200 (là ID của lịch học)
    for (int j = 1; j <= 200; j++) {
      await _plugin.cancel(j);
    }

    final now = DateTime.now();
    int scheduledCount = 0;
    print('🔔 Bắt đầu lên lịch thông báo từ ngày: $now');
    print('🔔 Tổng lichHoc: ${lichHoc.length}, lichThi: ${lichThi.length}');

    // DEBUG: In format dữ liệu thực tế
    for (var l in lichHoc.take(5)) {
      print(
          '🔔 LichHoc: thu="${l.thu}" | thoiGian="${l.thoiGian}" | gioHoc="${l.gioHoc}"');
    }

    final location = tz.getLocation('Asia/Ho_Chi_Minh');

    for (int i = 0; i <= 14; i++) {
      if (scheduledCount >= 200) break;

      final date = now.add(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);

      final classes =
          lichHoc.where((l) => _lichHocMatchesDate(l, dateOnly)).toList();

      // DEBUG: In kết quả match
      print(
          '🔔 Ngày ${dateOnly.toString().substring(0, 10)} weekday=${dateOnly.weekday}: ${classes.length} lớp');

      final exams = lichThi.where((l) {
        final ed = _parseDate(l.ngayThi);
        return ed != null &&
            ed.year == dateOnly.year &&
            ed.month == dateOnly.month &&
            ed.day == dateOnly.day;
      }).toList();

      if (classes.isEmpty && exams.isEmpty) continue;

      // 1. TỔNG HỢP NGÀY MAI (Lên lịch lúc 20:00 ngày hôm trước)
      if (i > 0) {
        if (scheduledCount >= 200) break;
        // Tính 20:00 hôm nay (ngày trước của date)
        final yesterday = date.subtract(const Duration(days: 1));
        final scheduleTime = tz.TZDateTime(
          location,
          yesterday.year,
          yesterday.month,
          yesterday.day,
          20,
          0,
        );

        final nowTZ = tz.TZDateTime.now(location);

        if (!scheduleTime.isBefore(nowTZ)) {
          final dateStr =
              '${dateOnly.day.toString().padLeft(2, '0')}/${dateOnly.month.toString().padLeft(2, '0')}';
          String body = '';
          if (classes.isNotEmpty) body += '📚 ${classes.length} ca học';
          if (exams.isNotEmpty) {
            if (body.isNotEmpty) body += ' & ';
            body += '📝 ${exams.length} ca thi';
          }
          body += ' vào ngày mai ($dateStr). ';

          final details = <String>[];
          for (var c in classes) details.add('${c.tenHocPhan} (${c.gioHoc})');
          for (var e in exams)
            details.add('${e.tenMonHoc} (Thi - ${e.gioBatDau})');

          body += details.take(3).join(', ');
          if (details.length > 3) {
            body += ' và ${details.length - 3} sự kiện khác...';
          }

          await _plugin.zonedSchedule(
            scheduledCount + 1,
            'Nhắc nhở lịch học ngày mai ($dateStr)',
            body,
            scheduleTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'schedule_channel',
                'Nhắc nhở lịch học',
                channelDescription:
                    'Thông báo lịch học vào 20:00 ngày hôm trước',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );

          print('🔔 Lên lịch TỔNG HỢP lúc $scheduleTime cho ngày $dateOnly');
          scheduledCount++;
        }
      }

      // 2. NHẮC TRƯỚC 1 TIẾNG CHO TỪNG CA HỌC (cho cả hôm nay và ngày mai)
      for (var c in classes) {
        if (scheduledCount >= 200) break;
        final timeParts = c.gioHoc.split(':');
        if (timeParts.length == 2) {
          final h = int.tryParse(timeParts[0]) ?? 0;
          final m = int.tryParse(timeParts[1]) ?? 0;
          final classTime =
              tz.TZDateTime(location, date.year, date.month, date.day, h, m);
          final reminderTime = classTime.subtract(const Duration(hours: 1));
          if (!reminderTime.isBefore(tz.TZDateTime.now(location))) {
            try {
              await _plugin.zonedSchedule(
                scheduledCount + 1,
                'Sắp tới giờ học!',
                'Môn ${c.tenHocPhan} sẽ bắt đầu lúc ${c.gioHoc} tại phòng ${c.phong}.',
                reminderTime,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'class_reminder_channel',
                    'Nhắc trước giờ học/thi',
                    channelDescription: 'Thông báo trước giờ học 1 tiếng',
                    importance: Importance.max,
                    priority: Priority.max,
                  ),
                  iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
              print(
                  '🔔 Lên lịch TRƯỚC 1 TIẾNG môn ${c.tenHocPhan} lúc $reminderTime');
              scheduledCount++;
            } catch (e) {
              print('⚠️ Lỗi khi zonedSchedule (Ca học): $e');
            }
          }
        }
      }

      // 3. NHẮC TRƯỚC 1 TIẾNG CHO TỪNG CA THI
      for (var e in exams) {
        if (scheduledCount >= 200) break;
        final timeParts = e.gioBatDau.split(':');
        if (timeParts.length == 2) {
          final h = int.tryParse(timeParts[0]) ?? 0;
          final m = int.tryParse(timeParts[1]) ?? 0;
          final examTime =
              tz.TZDateTime(location, date.year, date.month, date.day, h, m);
          final reminderTime = examTime.subtract(const Duration(hours: 1));

          if (!reminderTime.isBefore(tz.TZDateTime.now(location))) {
            try {
              await _plugin.zonedSchedule(
                scheduledCount + 1,
                'Sắp tới giờ thi!',
                'Môn ${e.tenMonHoc} sẽ thi lúc ${e.gioBatDau} tại phòng ${e.phong}.',
                reminderTime,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'class_reminder_channel',
                    'Nhắc trước giờ học/thi',
                    channelDescription: 'Thông báo trước giờ thi 1 tiếng',
                    importance: Importance.max,
                    priority: Priority.max,
                  ),
                  iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
              print(
                  '🔔 Lên lịch TRƯỚC 1 TIẾNG thi ${e.tenMonHoc} lúc $reminderTime');
              scheduledCount++;
            } catch (e) {
              print('⚠️ Lỗi khi zonedSchedule (Ca thi): $e');
            }
          }
        }
      }
    }
    print('🔔 Hoàn tất lên lịch. Tổng cộng $scheduledCount thông báo.');
    // Lên lịch thông báo xong thì lên lịch tạo thẻ
    await generateScheduleCards(mssv, lichHoc, lichThi);
  }

  static Future<void> generateScheduleCards(
      String mssv, List<LichHoc> lichHoc, List<LichThi> lichThi) async {
    if (mssv.isEmpty) return;
    if (!await isNotificationEnabled(mssv)) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // ── 1. Xác định điểm bắt đầu catch-up ──
    final catchupKey = 'last_catchup_time_$mssv';
    final lastMs = prefs.getInt(catchupKey);
    DateTime startDay;
    if (lastMs == null) {
      // Mặc định lùi về 3 ngày trước
      startDay = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3));
    } else {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      startDay = DateTime(last.year, last.month, last.day);
    }

    // Giới hạn an toàn: không bao giờ quét ngược quá 7 ngày
    final maxStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    if (startDay.isBefore(maxStart)) startDay = maxStart;

    // Quét từ startDay đến 14 ngày trong tương lai (đồng bộ với scheduleClasses)
    final endDay = DateTime(now.year, now.month, now.day).add(const Duration(days: 14));

    print('[Schedule Cards] Quét và sinh thẻ từ $startDay → $endDay (now=$now)');

    final dismissed = await NotificationService.getDismissedIds();
    final allNotifs = await NotificationService.getAllRaw();
    final existingIds = allNotifs.map((n) => n.id).toSet();
    final dismissedSet = dismissed.toSet();

    final startTimeStr = prefs.getString('notif_start_time_$mssv');
    final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;

    // Hàm lấy danh sách lớp học/thi theo ngày
    List<LichHoc> getLichHocForDate(DateTime date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return lichHoc.where((l) => _lichHocMatchesDate(l, dateOnly)).toList();
    }

    List<LichThi> getLichThiForDate(DateTime date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return lichThi.where((l) {
        final ed = _parseDate(l.ngayThi);
        return ed != null &&
            ed.year == dateOnly.year &&
            ed.month == dateOnly.month &&
            ed.day == dateOnly.day;
      }).toList();
    }

    // Vòng lặp qua từng ngày trong phạm vi
    for (DateTime day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))) {
      final dateOnly = DateTime(day.year, day.month, day.day);
      final classes = getLichHocForDate(dateOnly);
      final exams = getLichThiForDate(dateOnly);

      if (classes.isEmpty && exams.isEmpty) continue;

      // ── 1. THÔNG BÁO TỔNG HỢP (cho ngày mai / ngày học) ──
      // Lên lịch vào lúc 20:00 ngày hôm trước của dateOnly
      final yesterday = dateOnly.subtract(const Duration(days: 1));
      final notifyAt = DateTime(yesterday.year, yesterday.month, yesterday.day, 20, 0);
      final summaryId = 'schedule_reminder_${dateOnly.year}_${dateOnly.month}_${dateOnly.day}';

      if (!dismissedSet.contains(summaryId) && !existingIds.contains(summaryId)) {
        if (startTime == null || !notifyAt.isBefore(startTime)) {
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
          if (details.length > 3) {
            body += ' và ${details.length - 3} sự kiện khác...';
          }

          final title = 'Nhắc nhở lịch học ngày mai';

          await NotificationService.add(AppNotif(
            id: summaryId,
            title: title,
            body: body,
            targetTab: 1,
            ts: notifyAt,
          ));
          existingIds.add(summaryId);
        }
      }

      // ── 2. NHẮC TRƯỚC 1 TIẾNG TỪNG CA HỌC ──
      for (final c in classes) {
        final notifId = 'class_reminder_${dateOnly.year}_${dateOnly.month}_${dateOnly.day}_${c.tenHocPhan}';

        if (dismissedSet.contains(notifId)) continue;
        if (existingIds.contains(notifId)) continue;

        final timeParts = c.gioHoc.split(':');
        if (timeParts.length != 2) continue;
        final h = int.tryParse(timeParts[0]) ?? 0;
        final m = int.tryParse(timeParts[1]) ?? 0;
        final classTime = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, h, m);
        final reminderTime = classTime.subtract(const Duration(hours: 1));

        if (startTime == null || !reminderTime.isBefore(startTime)) {
          final notif = AppNotif(
            id: notifId,
            title: 'Sắp tới giờ học!',
            body: 'Môn ${c.tenHocPhan} sẽ bắt đầu lúc ${c.gioHoc} tại phòng ${c.phong}.',
            targetTab: 1,
            ts: reminderTime,
          );

          await NotificationService.add(notif);
          existingIds.add(notifId);

          // Đổ chuông native nếu sự kiện "upcoming" ngay lúc này (đáp ứng tính năng catch-up tức thời khi mở app)
          final isPast = now.isAfter(classTime);
          final isUpcoming = !isPast && now.isAfter(reminderTime) && now.isBefore(classTime);
          if (isUpcoming) {
            await LocalNotificationService.showImmediate(
              id: notifId.hashCode & 0x7FFFFFFF,
              title: 'Sắp tới giờ học!',
              body: 'Môn ${c.tenHocPhan} sẽ bắt đầu lúc ${c.gioHoc} tại phòng ${c.phong}.',
            );
          }
        }
      }

      // ── 3. NHẮC TRƯỚC 1 TIẾNG TỪNG CA THI ──
      for (final e in exams) {
        final notifId = 'exam_reminder_${dateOnly.year}_${dateOnly.month}_${dateOnly.day}_${e.tenMonHoc}';

        if (dismissedSet.contains(notifId)) continue;
        if (existingIds.contains(notifId)) continue;

        final timeParts = e.gioBatDau.split(':');
        if (timeParts.length != 2) continue;
        final h = int.tryParse(timeParts[0]) ?? 0;
        final m = int.tryParse(timeParts[1]) ?? 0;
        final examTime = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, h, m);
        final reminderTime = examTime.subtract(const Duration(hours: 1));

        if (startTime == null || !reminderTime.isBefore(startTime)) {
          final notif = AppNotif(
            id: notifId,
            title: 'Sắp tới giờ thi!',
            body: 'Môn ${e.tenMonHoc} sẽ thi lúc ${e.gioBatDau} tại phòng ${e.phong}.',
            targetTab: 1,
            ts: reminderTime,
          );

          await NotificationService.add(notif);
          existingIds.add(notifId);

          final isPast = now.isAfter(examTime);
          final isUpcoming = !isPast && now.isAfter(reminderTime) && now.isBefore(examTime);
          if (isUpcoming) {
            await LocalNotificationService.showImmediate(
              id: notifId.hashCode & 0x7FFFFFFF,
              title: 'Sắp tới giờ thi!',
              body: 'Môn ${e.tenMonHoc} sẽ thi lúc ${e.gioBatDau} tại phòng ${e.phong}.',
            );
          }
        }
      }
    }

    // Cập nhật mốc catch-up
    await prefs.setInt(catchupKey, now.millisecondsSinceEpoch);
    print('[Schedule Cards] ✅ Hoàn tất sinh thẻ.');
  }
}
