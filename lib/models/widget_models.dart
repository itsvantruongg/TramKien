import 'dart:convert';
import 'package:flutter/material.dart';

/// Cấu hình giao diện Widget (widget_theme_config.json)
class WidgetThemeConfig {
  /// 'single_day' | 'three_days' | 'seven_days'
  final String layoutMode;

  /// 'solid' (mặc định) | 'transparent'
  final String bgStyle;

  /// Hex string e.g. '#1C1C1E'
  final String bgColorHex;

  /// 0.0 to 1.0
  final double bgOpacity;

  /// Hex string e.g. '#FFFFFF'
  final String textPrimaryHex;

  /// Hex string e.g. '#98989D'
  final String textSecondaryHex;

  /// Hex string e.g. '#1D64F2'
  final String accentColorHex;

  /// Hex string e.g. '#26FFFFFF'
  final String borderColorHex;

  /// Đường dẫn file ảnh nền tùy chỉnh từ thiết bị
  final String? customBgImagePath;

  final bool showRoom;
  final bool showTime;
  final bool showTeacher;
  final bool showClassCode;
  final bool enableLockscreenNotification;

  const WidgetThemeConfig({
    required this.layoutMode,
    required this.bgStyle,
    required this.bgColorHex,
    required this.bgOpacity,
    required this.textPrimaryHex,
    required this.textSecondaryHex,
    required this.accentColorHex,
    this.borderColorHex = '#26FFFFFF',
    this.customBgImagePath,
    required this.showRoom,
    required this.showTime,
    required this.showTeacher,
    required this.showClassCode,
    this.enableLockscreenNotification = false,
  });

  /// Preset 1: Minimal Swiss (Tối giản Thụy Sĩ - Nền Tối)
  factory WidgetThemeConfig.minimalSwiss({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#1C1C1E',
      bgOpacity: 1.0,
      textPrimaryHex: '#FFFFFF',
      textSecondaryHex: '#CBD5E1',
      accentColorHex: '#1D64F2',
      borderColorHex: '#26FFFFFF',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Preset 2: Solid Light (Nền Sáng Tinh Gọn)
  factory WidgetThemeConfig.solidLight({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#FFFFFF',
      bgOpacity: 1.0,
      textPrimaryHex: '#0F172A',
      textSecondaryHex: '#64748B',
      accentColorHex: '#1D64F2',
      borderColorHex: '#E2E8F0',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Compatibility Preset: Frosted Glass maps to Solid Dark
  factory WidgetThemeConfig.frostedGlass({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig.minimalSwiss(layoutMode: layoutMode);
  }

  /// Preset 3: Ghost Mode (Trong suốt 100%)
  factory WidgetThemeConfig.ghostMode({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'transparent',
      bgColorHex: '#00000000',
      bgOpacity: 0.0,
      textPrimaryHex: '#FFFFFF',
      textSecondaryHex: '#CBD5E1',
      accentColorHex: '#0A84FF',
      borderColorHex: '#33FFFFFF',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Preset 4: Cyberpunk / Neon
  factory WidgetThemeConfig.cyberpunkNeon({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#0B0C10',
      bgOpacity: 1.0,
      textPrimaryHex: '#66FCF1',
      textSecondaryHex: '#45A29E',
      accentColorHex: '#FF0055',
      borderColorHex: '#2666FCF1',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Preset 5: Dark Obsidian (Bảng màu tối sâu sang trọng)
  factory WidgetThemeConfig.darkObsidian({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#0F172A',
      bgOpacity: 1.0,
      textPrimaryHex: '#FFFFFF',
      textSecondaryHex: '#94A3B8',
      accentColorHex: '#6366F1',
      borderColorHex: '#26FFFFFF',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Preset 6: Deep Forest (Bảng màu xanh rừng sâu)
  factory WidgetThemeConfig.deepForest({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#064E3B',
      bgOpacity: 1.0,
      textPrimaryHex: '#FFFFFF',
      textSecondaryHex: '#A7F3D0',
      accentColorHex: '#10B981',
      borderColorHex: '#26FFFFFF',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  /// Preset 7: Sunset Minimal (Bảng màu hoàng hôn rực rỡ)
  factory WidgetThemeConfig.sunsetMinimal({String layoutMode = 'single_day'}) {
    return WidgetThemeConfig(
      layoutMode: layoutMode,
      bgStyle: 'solid',
      bgColorHex: '#4C1D95',
      bgOpacity: 1.0,
      textPrimaryHex: '#FFFFFF',
      textSecondaryHex: '#F472B6',
      accentColorHex: '#EC4899',
      borderColorHex: '#26FFFFFF',
      showRoom: true,
      showTime: true,
      showTeacher: false,
      showClassCode: false,
      enableLockscreenNotification: false,
    );
  }

  factory WidgetThemeConfig.fromJson(Map<String, dynamic> json) {
    final rawBgStyle = json['bg_style'] as String?;
    final bgStyle = (rawBgStyle == 'transparent') ? 'transparent' : 'solid';
    return WidgetThemeConfig(
      layoutMode: json['layout_mode'] ?? 'single_day',
      bgStyle: bgStyle,
      bgColorHex: json['bg_color_hex'] ?? '#1C1C1E',
      bgOpacity: (bgStyle == 'transparent')
          ? 0.0
          : ((json['bg_opacity'] is num)
              ? (json['bg_opacity'] as num).toDouble().clamp(0.0, 1.0)
              : 1.0),
      textPrimaryHex: json['text_primary_hex'] ?? '#FFFFFF',
      textSecondaryHex: json['text_secondary_hex'] ?? '#98989D',
      accentColorHex: json['accent_color_hex'] ?? '#1D64F2',
      borderColorHex: json['border_color_hex'] ?? '#26FFFFFF',
      customBgImagePath: json['custom_bg_image_path'],
      showRoom: json['show_room'] ?? true,
      showTime: json['show_time'] ?? true,
      showTeacher: json['show_teacher'] ?? false,
      showClassCode: json['show_class_code'] ?? false,
      enableLockscreenNotification:
          json['enable_lockscreen_notification'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'layout_mode': layoutMode,
        'bg_style': bgStyle,
        'bg_color_hex': bgColorHex,
        'bg_opacity': bgOpacity,
        'text_primary_hex': textPrimaryHex,
        'text_secondary_hex': textSecondaryHex,
        'accent_color_hex': accentColorHex,
        'border_color_hex': borderColorHex,
        'custom_bg_image_path': customBgImagePath,
        'show_room': showRoom,
        'show_time': showTime,
        'show_teacher': showTeacher,
        'show_class_code': showClassCode,
        'enable_lockscreen_notification': enableLockscreenNotification,
      };

  WidgetThemeConfig copyWith({
    String? layoutMode,
    String? bgStyle,
    String? bgColorHex,
    double? bgOpacity,
    String? textPrimaryHex,
    String? textSecondaryHex,
    String? accentColorHex,
    String? borderColorHex,
    String? customBgImagePath,
    bool? showRoom,
    bool? showTime,
    bool? showTeacher,
    bool? showClassCode,
    bool? enableLockscreenNotification,
  }) {
    return WidgetThemeConfig(
      layoutMode: layoutMode ?? this.layoutMode,
      bgStyle: bgStyle ?? this.bgStyle,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      bgOpacity: (bgOpacity ?? this.bgOpacity).clamp(0.0, 1.0),
      textPrimaryHex: textPrimaryHex ?? this.textPrimaryHex,
      textSecondaryHex: textSecondaryHex ?? this.textSecondaryHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      borderColorHex: borderColorHex ?? this.borderColorHex,
      customBgImagePath: customBgImagePath != null
          ? (customBgImagePath.isEmpty ? null : customBgImagePath)
          : this.customBgImagePath,
      showRoom: showRoom ?? this.showRoom,
      showTime: showTime ?? this.showTime,
      showTeacher: showTeacher ?? this.showTeacher,
      showClassCode: showClassCode ?? this.showClassCode,
      enableLockscreenNotification:
          enableLockscreenNotification ?? this.enableLockscreenNotification,
    );
  }

  // ── Color Helpers ───────────────────────────────────────────
  static Color hexToColor(String hex, [double? opacity]) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    } else if (cleanHex.length == 3) {
      cleanHex =
          'FF${cleanHex[0]}${cleanHex[0]}${cleanHex[1]}${cleanHex[1]}${cleanHex[2]}${cleanHex[2]}';
    } else if (cleanHex.length != 8) {
      cleanHex = 'FFFFFFFF';
    }
    final int val = int.tryParse(cleanHex, radix: 16) ?? 0xFFFFFFFF;
    final color = Color(val);
    if (opacity != null) {
      return color.withOpacity(opacity.clamp(0.0, 1.0));
    }
    return color;
  }

  Color get backgroundColor {
    if (bgStyle == 'transparent') {
      return Colors.transparent;
    }
    return hexToColor(bgColorHex, bgOpacity);
  }

  Color get textPrimaryColor => hexToColor(textPrimaryHex);
  Color get textSecondaryColor => hexToColor(textSecondaryHex);
  Color get accentColor => hexToColor(accentColorHex);
  Color get borderColor => hexToColor(borderColorHex);
}

/// Ca học trong một ngày
class WidgetClassItem {
  final String courseName;

  /// Chuỗi tenLopTinChi (e.g. "TH4327_23CN 2") - bảo toàn nguyên vẹn
  final String classCode;

  final String timeSlot;
  final String room;
  final String teacher;
  final bool isCurrentOrNext;
  final bool isFinished;
  final bool isExam;

  const WidgetClassItem({
    required this.courseName,
    required this.classCode,
    required this.timeSlot,
    required this.room,
    required this.teacher,
    this.isCurrentOrNext = false,
    this.isFinished = false,
    this.isExam = false,
  });

  factory WidgetClassItem.fromJson(Map<String, dynamic> json) => WidgetClassItem(
        courseName: json['course_name'] ?? '',
        classCode: json['class_code'] ?? '',
        timeSlot: json['time_slot'] ?? '',
        room: json['room'] ?? '',
        teacher: json['teacher'] ?? '',
        isCurrentOrNext: json['is_current_or_next'] ?? false,
        isFinished: json['is_finished'] ?? false,
        isExam: json['is_exam'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'course_name': courseName,
        'class_code': classCode,
        'time_slot': timeSlot,
        'room': room,
        'teacher': teacher,
        'is_current_or_next': isCurrentOrNext,
        'is_finished': isFinished,
        'is_exam': isExam,
      };
}

/// Lịch học của một ngày
class WidgetDaySchedule {
  /// e.g. "HÔM NAY", "NGÀY MAI", "THỨ HAI", ...
  final String dayLabel;

  /// e.g. "20/10"
  final String dateStr;

  /// e.g. "T2", "T3", "CN"
  final String weekdayStr;

  final bool isToday;
  final bool isDimmed;
  final List<WidgetClassItem> classes;

  const WidgetDaySchedule({
    required this.dayLabel,
    required this.dateStr,
    required this.weekdayStr,
    required this.isToday,
    required this.isDimmed,
    required this.classes,
  });

  factory WidgetDaySchedule.fromJson(Map<String, dynamic> json) =>
      WidgetDaySchedule(
        dayLabel: json['day_label'] ?? '',
        dateStr: json['date_str'] ?? '',
        weekdayStr: json['weekday_str'] ?? '',
        isToday: json['is_today'] ?? false,
        isDimmed: json['is_dimmed'] ?? false,
        classes: (json['classes'] as List<dynamic>? ?? [])
            .map((c) => WidgetClassItem.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'day_label': dayLabel,
        'date_str': dateStr,
        'weekday_str': weekdayStr,
        'is_today': isToday,
        'is_dimmed': isDimmed,
        'classes': classes.map((c) => c.toJson()).toList(),
      };
}

/// Toàn bộ gói dữ liệu lịch học trích xuất (widget_schedule_data.json)
class WidgetScheduleData {
  final String updatedAt;
  final String widgetTitle;
  final String widgetSubtitle;
  final String layoutMode;
  final List<WidgetDaySchedule> days;

  const WidgetScheduleData({
    required this.updatedAt,
    required this.widgetTitle,
    required this.widgetSubtitle,
    required this.layoutMode,
    required this.days,
  });

  factory WidgetScheduleData.fromJson(Map<String, dynamic> json) =>
      WidgetScheduleData(
        updatedAt: json['updated_at'] ?? '',
        widgetTitle: json['widget_title'] ?? '',
        widgetSubtitle: json['widget_subtitle'] ?? '',
        layoutMode: json['layout_mode'] ?? 'single_day',
        days: (json['days'] as List<dynamic>? ?? [])
            .map((d) => WidgetDaySchedule.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'updated_at': updatedAt,
        'widget_title': widgetTitle,
        'widget_subtitle': widgetSubtitle,
        'layout_mode': layoutMode,
        'days': days.map((d) => d.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static WidgetScheduleData fromJsonString(String jsonStr) =>
      WidgetScheduleData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
