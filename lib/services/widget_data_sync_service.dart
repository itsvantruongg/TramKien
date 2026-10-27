import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../models/widget_models.dart';
import 'db/schedule_db.dart';

/// Dịch vụ đồng bộ dữ liệu và tính toán cửa sổ thời gian cho Widget (SPEC-WIDGET-STUDIO-01)
class WidgetDataSyncService {
  static const String keyWidgetScheduleData = 'widget_schedule_data';
  static const String keyWidgetScheduleDataSingleDay = 'widget_schedule_data_single_day';
  static const String keyWidgetScheduleDataTomorrow = 'widget_schedule_data_tomorrow';
  static const String keyWidgetScheduleDataThreeDays = 'widget_schedule_data_three_days';
  static const String keyWidgetScheduleDataSevenDays = 'widget_schedule_data_seven_days';
  static const String keyWidgetThemeConfig = 'widget_theme_config';
  static const int lockscreenNotificationId = 8888;
  static const MethodChannel _nativeChannel =
      MethodChannel('com.tramkien.hau/widget');

  /// Kích hoạt cập nhật native widget
  static Future<void> triggerNativeWidgetUpdate() async {
    try {
      await _nativeChannel
          .invokeMethod('updateWidget')
          .timeout(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('⚠️ triggerNativeWidgetUpdate: $e');
    }
  }

  /// Xóa sạch toàn bộ dữ liệu Widget khi đăng xuất và thông báo cho Native widget
  static Future<void> clearAllWidgetData({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final hasData = p.containsKey(keyWidgetScheduleData) ||
          p.containsKey(keyWidgetScheduleDataSingleDay) ||
          p.containsKey(keyWidgetScheduleDataThreeDays) ||
          p.containsKey(keyWidgetScheduleDataSevenDays) ||
          p.containsKey(keyWidgetScheduleDataTomorrow);
      await p.remove(keyWidgetScheduleData);
      await p.remove(keyWidgetScheduleDataSingleDay);
      await p.remove(keyWidgetScheduleDataThreeDays);
      await p.remove(keyWidgetScheduleDataSevenDays);
      await p.remove(keyWidgetScheduleDataTomorrow);
      if (!hasData) return;
      try {
        final fln = FlutterLocalNotificationsPlugin();
        await fln
            .cancel(lockscreenNotificationId)
            .timeout(const Duration(milliseconds: 300), onTimeout: () {});
      } catch (_) {}
      await triggerNativeWidgetUpdate();
    } catch (e) {
      debugPrint('⚠️ clearAllWidgetData: $e');
    }
  }

  /// Yêu cầu ghim widget ra màn hình chính (Android 8.0+)
  static Future<bool> requestPinWidget({String? layoutMode, String? variant}) async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>('pinWidget', {
        'layoutMode': layoutMode,
        'variant': variant,
      }).timeout(const Duration(milliseconds: 300));
      return res ?? false;
    } catch (e) {
      debugPrint('⚠️ requestPinWidget: $e');
      return false;
    }
  }

  /// Thu nhỏ app xuống nền an toàn (moveTaskToBack) khi người dùng muốn ra màn hình chính
  static Future<bool> minimizeApp() async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>('minimizeApp');
      return res ?? false;
    } catch (e) {
      debugPrint('⚠️ minimizeApp: $e');
      return false;
    }
  }

  /// Render ảnh chụp snapshot Native RemoteViews (SPEC-LIVE-PREVIEW)
  static Future<Uint8List?> renderWidgetPreview({
    required String layoutMode,
    String? variant,
    String? themeJson,
    String? dataJson,
  }) async {
    try {
      final res = await _nativeChannel.invokeMethod<Uint8List>('renderWidgetPreview', {
        'layoutMode': layoutMode,
        'variant': variant,
        'themeJson': themeJson,
        'dataJson': dataJson,
      });
      return res;
    } catch (e) {
      debugPrint('⚠️ renderWidgetPreview: $e');
      return null;
    }
  }

  /// Chuyển đổi Color sang chuỗi Hex chuẩn #RRGGBB
  static String colorToHex(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Mở hộp thoại chọn ảnh từ máy làm nền Widget
  static Future<String?> pickBackgroundImage() async {
    try {
      final res = await _nativeChannel
          .invokeMethod<String>('pickImage')
          .timeout(const Duration(seconds: 30));
      return res;
    } catch (e) {
      debugPrint('⚠️ pickBackgroundImage: $e');
      return null;
    }
  }

  /// Lấy route điều hướng deep link từ native (nếu mở từ widget shortcut)
  static Future<String?> getInitialRoute() async {
    try {
      return await _nativeChannel
          .invokeMethod<String>('getInitialRoute')
          .timeout(const Duration(milliseconds: 300));
    } catch (e) {
      return null;
    }
  }

  /// Lấy target_tab điều hướng từ native (nếu mở từ widget tap)
  static Future<int?> getInitialTargetTab() async {
    try {
      return await _nativeChannel
          .invokeMethod<int>('getInitialTargetTab')
          .timeout(const Duration(milliseconds: 300));
    } catch (e) {
      return null;
    }
  }

  // ── 1. ĐỒNG BỘ DỮ LIỆU & LƯU TRỮ OFFLINE-FIRST ──────────────────────────

  /// Lưu cấu hình giao diện Widget
  static Future<void> saveThemeConfig(
    WidgetThemeConfig config, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(keyWidgetThemeConfig, jsonEncode(config.toJson()));
  }

  /// Nạp cấu hình giao diện Widget (fallback về Frosted Glass)
  static Future<WidgetThemeConfig> getThemeConfig({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final jsonStr = p.getString(keyWidgetThemeConfig);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return WidgetThemeConfig.fromJson(map);
      } catch (e) {
        debugPrint('⚠️ Error parsing widget theme config: $e');
      }
    }
    return WidgetThemeConfig.frostedGlass();
  }

  /// Lưu gói dữ liệu lịch học widget_schedule_data.json
  static Future<void> saveScheduleData(
    WidgetScheduleData data, {
    SharedPreferences? prefs,
    String? layoutMode,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(keyWidgetScheduleData, data.toJsonString());
    if (layoutMode != null) {
      await p.setString(getPrefKeyForMode(layoutMode), data.toJsonString());
    } else {
      await p.setString(getPrefKeyForMode(data.layoutMode), data.toJsonString());
    }
  }

  /// Lấy SharedPreferences key tương ứng theo layoutMode
  static String getPrefKeyForMode(String mode) {
    switch (mode) {
      case 'tomorrow':
        return keyWidgetScheduleDataTomorrow;
      case 'three_days':
        return keyWidgetScheduleDataThreeDays;
      case 'seven_days':
        return keyWidgetScheduleDataSevenDays;
      case 'single_day':
      default:
        return keyWidgetScheduleDataSingleDay;
    }
  }

  /// Nạp gói dữ liệu lịch học đã lưu (hỗ trợ đọc theo layoutMode độc lập)
  static Future<WidgetScheduleData?> getScheduleData({
    SharedPreferences? prefs,
    String? layoutMode,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (layoutMode != null) {
      final key = getPrefKeyForMode(layoutMode);
      final jsonStr = p.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          return WidgetScheduleData.fromJsonString(jsonStr);
        } catch (e) {
          debugPrint('⚠️ Error parsing widget schedule data ($layoutMode): $e');
        }
      }
    }
    final jsonStr = p.getString(keyWidgetScheduleData);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return WidgetScheduleData.fromJsonString(jsonStr);
      } catch (e) {
        debugPrint('⚠️ Error parsing widget schedule data: $e');
      }
    }
    return null;
  }

  /// Nạp lịch học từ SQLite ScheduleDb và trích xuất dữ liệu widget offline
  static Future<WidgetScheduleData> loadAndSyncFromDb({
    DateTime? currentTime,
    String? layoutMode,
    Database? db,
    SharedPreferences? prefs,
    List<LichHoc>? sourceSchedules,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    bool updateNotification = true,
    WidgetThemeConfig? themeConfig,
  }) async {
    final now = currentTime ?? DateTime.now();
    final currentConfig = themeConfig ?? await getThemeConfig(prefs: prefs);
    final mode = layoutMode ?? currentConfig.layoutMode;

    List<LichHoc> schedules;
    List<LichThi> exams = [];
    if (sourceSchedules != null) {
      schedules = sourceSchedules;
    } else {
      try {
        schedules = await ScheduleDb.getLichHoc();
      } catch (e) {
        debugPrint('⚠️ ScheduleDb.getLichHoc offline read fallback: $e');
        schedules = [];
      }
      try {
        exams = await ScheduleDb.getLichThi();
      } catch (e) {
        debugPrint('⚠️ ScheduleDb.getLichThi offline read fallback: $e');
        exams = [];
      }
    }

    // Tự động tính toán đồng thời các widget độc lập
    final singleDayData = calculateScheduleWindow(
      allSchedules: schedules,
      allExams: exams,
      layoutMode: 'single_day',
      currentTime: now,
    );
    final tomorrowData = calculateTomorrowSchedule(
      allSchedules: schedules,
      allExams: exams,
      currentTime: now,
    );
    final threeDaysData = calculateScheduleWindow(
      allSchedules: schedules,
      allExams: exams,
      layoutMode: 'three_days',
      currentTime: now,
    );
    final sevenDaysData = calculateScheduleWindow(
      allSchedules: schedules,
      allExams: exams,
      layoutMode: 'seven_days',
      currentTime: now,
    );

    // Lưu các key SharedPreferences riêng biệt
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(keyWidgetScheduleDataSingleDay, singleDayData.toJsonString());
    await p.setString(keyWidgetScheduleDataTomorrow, tomorrowData.toJsonString());
    await p.setString(keyWidgetScheduleDataThreeDays, threeDaysData.toJsonString());
    await p.setString(keyWidgetScheduleDataSevenDays, sevenDaysData.toJsonString());

    // Dữ liệu tương ứng với mode yêu cầu (hoặc mode đang cấu hình)
    final scheduleData = mode == 'tomorrow'
        ? tomorrowData
        : (mode == 'three_days'
            ? threeDaysData
            : (mode == 'seven_days' ? sevenDaysData : singleDayData));

    // Đồng thời vẫn lưu keyWidgetScheduleData để tương thích ngược
    await p.setString(keyWidgetScheduleData, scheduleData.toJsonString());

    if (updateNotification) {
      if (currentConfig.enableLockscreenNotification) {
        try {
          await updatePersistentNotificationCard(
            scheduleData,
            themeConfig: currentConfig,
            plugin: notificationsPlugin,
          );
        } catch (e) {
          debugPrint('⚠️ Persistent notification card update error: $e');
        }
      } else {
        try {
          final fln = notificationsPlugin ?? FlutterLocalNotificationsPlugin();
          await fln
              .cancel(lockscreenNotificationId)
              .timeout(const Duration(milliseconds: 300), onTimeout: () {});
        } catch (e) {
          debugPrint('⚠️ Persistent notification card cancel error: $e');
        }
      }
    }

    return scheduleData;
  }

  // ── 2. SMART TIME-WINDOW ENGINE (TÍNH TOÁN CỬA SỔ HIỂN THỊ) ─────────────

  /// Tính toán dữ liệu hiển thị theo bảng Ma trận thời gian (SPEC 2.1)
  static WidgetScheduleData calculateScheduleWindow({
    required List<LichHoc> allSchedules,
    List<LichThi>? allExams,
    required String layoutMode,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    switch (layoutMode) {
      case 'tomorrow':
        return calculateTomorrowSchedule(allSchedules: allSchedules, allExams: allExams, currentTime: now);
      case 'three_days':
        return _calculateThreeDaysWindow(allSchedules, now, allExams: allExams);
      case 'seven_days':
        return _calculateSevenDaysWindow(allSchedules, now, allExams: allExams);
      case 'single_day':
      default:
        return _calculateSingleDayWindow(allSchedules, now, allExams: allExams);
    }
  }

  /// Chế độ Ngày Mai (4x2):
  /// - Khóa cứng nạp lịch ngày kế tiếp (now.add(Duration(days: 1)))
  /// - Header tách biệt: Trái "Lịch ngày mai", Phải "Thứ X, dd/MM"
  static WidgetScheduleData calculateTomorrowSchedule({
    required List<LichHoc> allSchedules,
    List<LichThi>? allExams,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    const String title = 'Lịch ngày mai';
    final String subtitle = '${formatWeekdayFull(tomorrow.weekday)}, ${formatDateShort(tomorrow)}';

    final classes = _extractClassesForDate(
      allSchedules: allSchedules,
      allExams: allExams,
      targetDate: tomorrow,
      now: now,
      isTargetToday: false,
    );

    final daySchedule = WidgetDaySchedule(
      dayLabel: 'NGÀY MAI',
      dateStr: formatDateShort(tomorrow),
      weekdayStr: formatWeekdayShort(tomorrow.weekday),
      isToday: false,
      isDimmed: false,
      classes: classes,
    );

    return WidgetScheduleData(
      updatedAt: now.toIso8601String(),
      widgetTitle: title,
      widgetSubtitle: subtitle,
      layoutMode: 'tomorrow',
      days: [daySchedule],
    );
  }

  /// Chế độ 1 Ngày (Chuẩn):
  /// - Trung thành với ngày hôm nay để sinh viên tra cứu.
  /// - Tiêu đề "Lịch hôm nay", nạp ca học hôm nay. Widget Ngày mai là widget chuyên biệt độc lập.
  static WidgetScheduleData _calculateSingleDayWindow(
    List<LichHoc> allSchedules,
    DateTime now, {
    List<LichThi>? allExams,
  }) {
    final DateTime targetDate = DateTime(now.year, now.month, now.day);

    const String title = 'Lịch hôm nay';
    final String subtitle = '${formatWeekdayFull(targetDate.weekday)}, ${formatDateShort(targetDate)}';
    const String dayLabel = 'HÔM NAY';

    final classes = _extractClassesForDate(
      allSchedules: allSchedules,
      allExams: allExams,
      targetDate: targetDate,
      now: now,
      isTargetToday: true,
    );

    final daySchedule = WidgetDaySchedule(
      dayLabel: dayLabel,
      dateStr: formatDateShort(targetDate),
      weekdayStr: formatWeekdayShort(targetDate.weekday),
      isToday: true,
      isDimmed: false,
      classes: classes,
    );

    return WidgetScheduleData(
      updatedAt: now.toIso8601String(),
      widgetTitle: title,
      widgetSubtitle: subtitle,
      layoutMode: 'single_day',
      days: [daySchedule],
    );
  }

  /// Chế độ 3 Ngày (Rolling Window):
  /// - Hiển thị 72 giờ (3 ngày liên tiếp: Hôm nay, Ngày mai, Ngày kia).
  /// - Thẻ Hôm nay luôn giữ opacity 1.0, isDimmed = false và nổi bật bằng viền Accent.
  /// - Đến 00:00 nửa đêm: Cuộn cửa sổ (Rolling Window): Hôm nay mới trở thành Day 0, nạp ngày thứ 3 mới.
  static WidgetScheduleData _calculateThreeDaysWindow(
    List<LichHoc> allSchedules,
    DateTime now, {
    List<LichThi>? allExams,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final dayEnd = today.add(const Duration(days: 2));
    final days = <WidgetDaySchedule>[];

    for (int i = 0; i < 3; i++) {
      final date = today.add(Duration(days: i));
      final bool isCurrentDayToday = i == 0;
      const bool isDimmed = false;

      String label;
      if (i == 0) {
        label = 'HÔM NAY';
      } else if (i == 1) {
        label = 'NGÀY MAI';
      } else {
        label = formatWeekdayLong(date.weekday);
      }

      final classes = _extractClassesForDate(
        allSchedules: allSchedules,
        allExams: allExams,
        targetDate: date,
        now: now,
        isTargetToday: isCurrentDayToday,
      );

      days.add(WidgetDaySchedule(
        dayLabel: label,
        dateStr: formatDateShort(date),
        weekdayStr: formatWeekdayShort(date.weekday),
        isToday: isCurrentDayToday,
        isDimmed: isDimmed,
        classes: classes,
      ));
    }

    return WidgetScheduleData(
      updatedAt: now.toIso8601String(),
      widgetTitle: 'Lịch 3 ngày',
      widgetSubtitle: '${formatDateShort(today)} – ${formatDateShort(dayEnd)}',
      layoutMode: 'three_days',
      days: days,
    );
  }

  /// Chế độ 7 Ngày (Weekly):
  /// - Lúc 00:00 hàng ngày: Vạch Accent và chữ Bold nhảy sang Thứ mới. Các thứ đã qua chuyển sang màu xám mờ (isDimmed = true).
  /// - Tối Chủ nhật lúc 20:00: Lật sang Tuần mới, nạp thời khóa biểu tuần kế tiếp (Thứ 2 đến CN tuần sau).
  static WidgetScheduleData _calculateSevenDaysWindow(
    List<LichHoc> allSchedules,
    DateTime now, {
    List<LichThi>? allExams,
  }) {
    final bool isSundayEveningRollover =
        now.weekday == DateTime.sunday && now.hour >= 20;

    DateTime startOfWeekMonday;

    if (isSundayEveningRollover) {
      // Lật sang Tuần mới (bắt đầu từ Thứ 2 ngày mai)
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      startOfWeekMonday = tomorrow;
    } else {
      // Tuần hiện tại (bắt đầu từ Thứ 2 của tuần này)
      final todayMidnight = DateTime(now.year, now.month, now.day);
      startOfWeekMonday =
          todayMidnight.subtract(Duration(days: now.weekday - 1));
    }

    final weekEndSunday = startOfWeekMonday.add(const Duration(days: 6));
    const String title = 'Lịch tuần';
    final String subtitle = '${formatDateShort(startOfWeekMonday)} – ${formatDateShort(weekEndSunday)}';

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final days = <WidgetDaySchedule>[];

    for (int i = 0; i < 7; i++) {
      final date = startOfWeekMonday.add(Duration(days: i));
      final bool isToday = !isSundayEveningRollover &&
          date.year == todayMidnight.year &&
          date.month == todayMidnight.month &&
          date.day == todayMidnight.day;

      // Các thứ đã qua chuyển sang màu xám mờ
      final bool isDimmed =
          !isSundayEveningRollover && date.isBefore(todayMidnight);

      String label;
      if (isToday) {
        label = 'HÔM NAY';
      } else {
        label = formatWeekdayLong(date.weekday);
      }

      final classes = _extractClassesForDate(
        allSchedules: allSchedules,
        allExams: allExams,
        targetDate: date,
        now: now,
        isTargetToday: isToday,
      );

      days.add(WidgetDaySchedule(
        dayLabel: label,
        dateStr: formatDateShort(date),
        weekdayStr: formatWeekdayShort(date.weekday),
        isToday: isToday,
        isDimmed: isDimmed,
        classes: classes,
      ));
    }

    return WidgetScheduleData(
      updatedAt: now.toIso8601String(),
      widgetTitle: title,
      widgetSubtitle: subtitle,
      layoutMode: 'seven_days',
      days: days,
    );
  }

  // ── 3. TRÍCH XUẤT VÀ KHỚP LỊCH HỌC THEO NGÀY ────────────────────────────

  /// Lọc danh sách LichHoc khớp với targetDate và định dạng thành WidgetClassItem
  static List<WidgetClassItem> _extractClassesForDate({
    required List<LichHoc> allSchedules,
    List<LichThi>? allExams,
    required DateTime targetDate,
    required DateTime now,
    required bool isTargetToday,
  }) {
    final matched = allSchedules
        .where((l) => lichHocMatchesDate(l, targetDate))
        .toList();

    // Sắp xếp theo tiết bắt đầu
    matched.sort((a, b) => a.tietBatDau.compareTo(b.tietBatDau));

    final List<WidgetClassItem> items = [];
    bool foundNextOrCurrent = false;

    final targetMidnight =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final bool isPastDate = targetMidnight.isBefore(todayMidnight);

    for (final l in matched) {
      bool isFinished = false;
      bool isCurrentOrNext = false;

      if (isPastDate) {
        isFinished = true;
      } else if (isTargetToday) {
        // Kiểm tra giờ kết thúc của ca học
        final endMinuteOfDay = _parseTimeOfDayInMinutes(l.gioKetThuc);
        final currentMinuteOfDay = now.hour * 60 + now.minute;

        if (endMinuteOfDay != null && currentMinuteOfDay > endMinuteOfDay) {
          isFinished = true;
        } else {
          if (!foundNextOrCurrent) {
            isCurrentOrNext = true;
            foundNextOrCurrent = true;
          }
        }
      } else {
        // Ngày tương lai
        isFinished = false;
        if (!foundNextOrCurrent) {
          isCurrentOrNext = true;
          foundNextOrCurrent = true;
        }
      }

      // SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 (AC-01):
      // Bảo toàn 100% ca học hôm nay (kể cả đã kết thúc: now > gioKetThuc) với cờ isFinished = true.
      // Không tự động drop/continue để tránh widget 1 ngày, 3 ngày, 7 ngày bị rơi vào trạng thái
      // "Không có lịch / Hôm nay nghỉ" sai lệch và ô Tổng kết tuần đếm nhầm ngày trống.

      // Format time slot: e.g. "12:45 – 17:00 (T8–12)"
      final cleanTiet = l.tiet
          .replaceAll('T', '')
          .replaceAll('t', '')
          .replaceAll('-', '–')
          .trim();
      final fullTime = l.gioHocFull
          .replaceAll(' - ', ' – ')
          .replaceAll('-', '–')
          .trim();
      final timeSlot = fullTime.isNotEmpty
          ? '$fullTime (T$cleanTiet)'
          : (cleanTiet.isNotEmpty ? 'T$cleanTiet' : '');

      // Format room: e.g. "P.M-M5.03"
      String room = l.phong.trim();
      if (room.isNotEmpty &&
          !room.toUpperCase().startsWith('P.') &&
          !room.toUpperCase().startsWith('P ')) {
        room = 'P.$room';
      }

      items.add(WidgetClassItem(
        courseName: l.tenHocPhan.trim(),
        // AC-02: Bảo toàn nguyên vẹn chuỗi tenLopTinChi (e.g. TH4327_23CN 2)
        classCode: l.tenLopTinChi.trim(),
        timeSlot: timeSlot,
        room: room.isEmpty ? '-' : room,
        teacher: l.giaoVien.trim(),
        isCurrentOrNext: isCurrentOrNext,
        isFinished: isFinished,
        isExam: false,
      ));
    }

    // Ghép lịch thi cho targetDate
    if (allExams != null && allExams.isNotEmpty) {
      for (final exam in allExams) {
        final parts = exam.ngayThi.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d == targetDate.day && m == targetDate.month && y == targetDate.year) {
            String examRoom = exam.phong.trim();
            if (examRoom.isNotEmpty && !examRoom.toUpperCase().startsWith('P.') && !examRoom.toUpperCase().startsWith('P ')) {
              examRoom = 'P.$examRoom';
            }
            final title = exam.tenMonHoc.startsWith('[THI]') ? exam.tenMonHoc : '[THI] ${exam.tenMonHoc}';
            items.add(WidgetClassItem(
              courseName: title,
              classCode: 'SBD: ${exam.sooBaoDanh}',
              timeSlot: exam.gioBatDau.isNotEmpty ? exam.gioBatDau : '07:30',
              room: examRoom.isNotEmpty ? examRoom : '-',
              teacher: exam.hinhThucThi,
              isCurrentOrNext: false,
              isFinished: false,
              isExam: true,
            ));
          }
        }
      }
    }

    return items;
  }

  /// Định dạng kết hợp Thời gian & Địa điểm (e.g. "12:45 – 17:00 (T8–12) • P.M-M5.03")
  static String formatHybridTimeAndRoom({
    required String timeSlot,
    required String room,
    bool showTime = true,
    bool showRoom = true,
    String? classCode,
    bool showClassCode = false,
    String? teacher,
    bool showTeacher = false,
  }) {
    final parts = <String>[];
    if (showTime && timeSlot.isNotEmpty) parts.add(timeSlot);
    if (showRoom && room.isNotEmpty && room != '-') parts.add(room);
    if (showTeacher && teacher != null && teacher.isNotEmpty) {
      parts.add(teacher);
    }
    if (showClassCode && classCode != null && classCode.isNotEmpty) {
      parts.add(classCode);
    }
    return parts.join(' • ');
  }

  /// Khớp lịch học theo thứ và dải thời gian thoiGian (dd/MM/yyyy - dd/MM/yyyy)
  static bool lichHocMatchesDate(LichHoc l, DateTime date) {
    final thuStr = l.thu.replaceAll('Thứ', '').trim();
    final thuNum = int.tryParse(thuStr);
    if (thuNum == null || thuNum < 2 || thuNum > 8) return false;
    final expectedWeekday = thuNum == 8 ? 7 : thuNum - 1;
    if (date.weekday != expectedWeekday) return false;

    final tg = l.thoiGian.trim();
    if (tg.isEmpty) {
      // Nếu không có chuỗi thời gian dải, chỉ so sánh theo thứ
      return true;
    }

    final dateMatches = RegExp(r'\d{1,2}/\d{1,2}/\d{4}')
        .allMatches(tg)
        .map((m) => m.group(0)!)
        .toList();

    if (dateMatches.length < 2) return true;

    DateTime? parseDMY(String s) {
      final p = s.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      }
      return null;
    }

    final start = parseDMY(dateMatches[0]);
    final end = parseDMY(dateMatches[1]);
    if (start == null || end == null) return true;

    final targetDate = DateTime(date.year, date.month, date.day);
    return !targetDate.isBefore(start) && !targetDate.isAfter(end);
  }

  static int? _parseTimeOfDayInMinutes(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        return h * 60 + m;
      }
    }
    return null;
  }

  // ── 4. THẺ GHIM YÊN LẶNG ANDROID LOCKSCREEN / AOD (AC-07) ─────────────────

  /// Cập nhật Persistent Silent Notification Card trên Android Màn hình khóa
  static Future<void> updatePersistentNotificationCard(
    WidgetScheduleData data, {
    WidgetThemeConfig? themeConfig,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final fln = plugin ?? FlutterLocalNotificationsPlugin();
    final config = themeConfig ?? await getThemeConfig();

    // AC-03: Tuyệt đối không tự ý đẩy thông báo trừ khi enable_lockscreen_notification được bật
    if (!config.enableLockscreenNotification) {
      try {
        await fln
            .cancel(lockscreenNotificationId)
            .timeout(const Duration(milliseconds: 300), onTimeout: () {});
      } catch (_) {}
      return;
    }

    final activeDay = data.days.firstWhere(
      (d) => d.isToday || d.dayLabel == 'NGÀY MAI',
      orElse: () => data.days.first,
    );

    final notificationTitle = '${data.widgetTitle} • ${data.widgetSubtitle}';

    String notificationBody;
    if (activeDay.classes.isEmpty) {
      notificationBody = 'Không có ca học nào trong ngày.';
    } else {
      final lines = <String>[];
      for (final c in activeDay.classes) {
        final codePart = (themeConfig?.showClassCode ?? true) &&
                c.classCode.isNotEmpty
            ? ' [${c.classCode}]'
            : '';
        final roomPart = (themeConfig?.showRoom ?? true) ? ' ${c.room}' : '';
        final timePart = (themeConfig?.showTime ?? true)
            ? '${c.timeSlot.split(' ')[0]} '
            : '';
        lines.add('$timePart$roomPart • ${c.courseName.toUpperCase()}$codePart');
      }
      notificationBody = lines.join('\n');
    }

    // AC-07: Thẻ ghim yên lặng với setOngoing(true), silent (low priority), không rung không chuông
    final details = buildLockscreenNotificationDetails(
      title: notificationTitle,
      body: notificationBody,
      classCount: activeDay.classes.length,
    );

    try {
      await fln
          .show(
            lockscreenNotificationId,
            notificationTitle,
            notificationBody,
            details,
          )
          .timeout(const Duration(milliseconds: 500), onTimeout: () {});
    } catch (e) {
      debugPrint('⚠️ Local notification show skipped/failed (e.g. in test env): $e');
    }
  }

  /// Khởi tạo cấu hình NotificationDetails cho thẻ ghim yên lặng ngoài màn hình khóa (AC-07)
  static NotificationDetails buildLockscreenNotificationDetails({
    required String title,
    required String body,
    required int classCount,
  }) {
    final androidDetails = AndroidNotificationDetails(
      'schedule_lockscreen_card',
      'Lịch học Màn hình khóa',
      channelDescription:
          'Thẻ ghim thông tin lịch học thường trực trên màn hình khóa và AOD',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      enableVibration: false,
      playSound: false,
      icon: 'ic_notification',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '$classCount ca học',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  // ── 5. ĐỊNH DẠNG VIBRANCY ĐƠN SẮC MÀN HÌNH KHÓA IOS (AC-08) ──────────────

  /// Định dạng 2 dòng súc tích cho widget accessoryRectangular trên iOS Lock Screen
  /// Ví dụ chuẩn AC-08:
  /// T2, 19/10 • 2 CA HỌC HÔM NAY
  /// 07:00 (T1-3)  P.I801 • KT MÁY TÍNH
  static String formatIosLockScreenVibrancy(WidgetScheduleData data) {
    if (data.days.isEmpty) {
      return 'LỊCH HỌC • KHÔNG CÓ DỮ LIỆU\nTẬN HƯỞNG NGÀY NGHỈ';
    }

    final activeDay = data.days.firstWhere(
      (d) => d.isToday || d.dayLabel == 'NGÀY MAI',
      orElse: () => data.days.first,
    );

    final String line1;
    if (activeDay.classes.isEmpty) {
      line1 = '${activeDay.weekdayStr}, ${activeDay.dateStr} • KHÔNG CÓ CA HỌC';
    } else {
      line1 =
          '${activeDay.weekdayStr}, ${activeDay.dateStr} • ${activeDay.classes.length} CA HỌC ${activeDay.dayLabel}';
    }

    final String line2;
    if (activeDay.classes.isEmpty) {
      line2 = 'TẬN HƯỞNG NGÀY NGHỈ';
    } else {
      final nextClass = activeDay.classes.firstWhere(
        (c) => c.isCurrentOrNext,
        orElse: () => activeDay.classes.first,
      );
      line2 =
          '${nextClass.timeSlot}  ${nextClass.room} • ${nextClass.courseName.toUpperCase()}';
    }

    return '$line1\n$line2';
  }

  // ── 6. FORMATTERS TIẾNG VIỆT CHUẨN THỤY SĨ ──────────────────────────────

  static String formatWeekdayFull(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
      default:
        return 'Chủ Nhật';
    }
  }

  static String formatWeekdayTitle(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
      default:
        return 'CN';
    }
  }

  static String formatWeekdayLong(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'THỨ HAI';
      case DateTime.tuesday:
        return 'THỨ BA';
      case DateTime.wednesday:
        return 'THỨ TƯ';
      case DateTime.thursday:
        return 'THỨ NĂM';
      case DateTime.friday:
        return 'THỨ SÁU';
      case DateTime.saturday:
        return 'THỨ BẢY';
      case DateTime.sunday:
      default:
        return 'CHỦ NHẬT';
    }
  }

  static String formatWeekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
      default:
        return 'CN';
    }
  }

  static String formatDateShort(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  static String formatVietnameseSubtitle(DateTime date) {
    final weekday = formatWeekdayLong(date.weekday);
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$weekday, $d/$m/${date.year}';
  }

  /// Kiểm tra chuỗi có chứa emoji nào hay không (AC-06: Tuyệt đối không dùng emoji)
  static bool containsEmoji(String text) {
    final regex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    );
    return regex.hasMatch(text);
  }
}
