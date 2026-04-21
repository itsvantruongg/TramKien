import 'dart:io';
//import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:android_intent_plus/android_intent_plus.dart';
// import 'package:android_intent_plus/flag.dart';
import '../models/models.dart';

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
    // ta chỉ xóa các ID từ 1 đến 100 (là ID của lịch học)
    for (int j = 1; j <= 100; j++) {
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
      if (scheduledCount >= 60) break;

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

      // 1. TỔNG HỢP NGÀY MAI (Chỉ lên lịch vào 20:00 ngày hôm trước, i > 0 vì ngày mai so với hôm qua)
      // THAY TOÀN BỘ BLOCK "1. TỔNG HỢP NGÀY MAI"
      if (i > 0) {
        // Tính 16:30 hôm nay (ngày trước của date)
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
                    'Thông báo lịch học vào 16:30 ngày hôm trước',
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
        if (scheduledCount >= 60) break;
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
        if (scheduledCount >= 60) break;
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
  }
}
