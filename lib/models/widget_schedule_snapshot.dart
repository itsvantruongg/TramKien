import 'dart:convert';
import 'widget_session.dart';
import '../services/widget/widget_time_utils.dart';

/// Bản chụp lịch JSON dùng chung cho phân hệ Widget (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01)
class WidgetScheduleSnapshot {
  static const int currentVersion = 1;
  static const String defaultTimeZone = 'Asia/Ho_Chi_Minh';

  final int version;
  final int generatedAt; // epoch milliseconds
  final String tz;
  final List<Session> sessions;

  const WidgetScheduleSnapshot({
    this.version = currentVersion,
    required this.generatedAt,
    this.tz = defaultTimeZone,
    required this.sessions,
  });

  /// Kiểm tra tính hợp lệ của bản chụp
  bool get isValid => version == currentVersion && generatedAt > 0;

  /// Kiểm tra xem bản chụp có quá cũ hay không (mặc định 180 ngày để hỗ trợ học kỳ/nghỉ hè)
  bool isStale({
    Duration maxAge = const Duration(days: 180),
    DateTime? now,
  }) {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return (nowMs - generatedAt) > maxAge.inMilliseconds;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'generatedAt': generatedAt,
        'tz': tz,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory WidgetScheduleSnapshot.fromJson(Map<String, dynamic> json) {
    final version = json['version'] is int
        ? json['version'] as int
        : int.tryParse(json['version']?.toString() ?? '1') ?? 1;

    final genAt = json['generatedAt'] is int
        ? json['generatedAt'] as int
        : int.tryParse(json['generatedAt']?.toString() ?? '0') ?? 0;

    final tz = (json['tz'] as String?) ?? defaultTimeZone;

    final rawSessions = json['sessions'] as List<dynamic>? ?? [];
    final sessions = rawSessions
        .whereType<Map<String, dynamic>>()
        .map(Session.fromJson)
        .toList();

    return WidgetScheduleSnapshot(
      version: version,
      generatedAt: genAt,
      tz: tz,
      sessions: sessions,
    );
  }

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  factory WidgetScheduleSnapshot.fromJsonString(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Snapshot JSON must be an object');
    }
    return WidgetScheduleSnapshot.fromJson(decoded);
  }

  /// Lấy toàn bộ các buổi học/thi trong ngày [date] theo giờ Việt Nam
  List<Session> getSessionsForDate(DateTime date) {
    return sessions
        .where((s) => WidgetTimeUtils.isSameVnDay(s.start, date))
        .toList();
  }

  /// Lấy danh sách các buổi học/thi hôm nay so với mốc [now]
  List<Session> getTodaySessions(DateTime now) {
    return getSessionsForDate(now);
  }

  /// Lấy các môn hôm nay còn lại (đang diễn ra hoặc sắp tới, loại bỏ các môn đã qua)
  List<Session> getRemainingTodaySessions(DateTime now) {
    final today = getTodaySessions(now);
    return today
        .where((s) => s.calculateStatus(now) != SessionStatus.past)
        .toList();
  }

  /// Lấy ca học/thi đang diễn ra tại mốc [now]
  /// Nếu có nhiều ca, ưu tiên ca thi, sau đó ưu tiên ca bắt đầu sớm hơn
  Session? getActiveSession(DateTime now) {
    final activeSessions = sessions
        .where((s) => s.calculateStatus(now) == SessionStatus.current)
        .toList();

    if (activeSessions.isEmpty) return null;

    activeSessions.sort((a, b) {
      // Ưu tiên 1: Lịch thi
      if (a.kind == SessionKind.examSession &&
          b.kind != SessionKind.examSession) {
        return -1;
      }
      if (b.kind == SessionKind.examSession &&
          a.kind != SessionKind.examSession) {
        return 1;
      }
      // Ưu tiên 2: Bắt đầu sớm hơn
      return a.startMs.compareTo(b.startMs);
    });

    return activeSessions.first;
  }

  /// Lấy ca sắp tới kế tiếp theo thứ tự ưu tiên của Mục 3.1:
  /// 1. Lịch thi sắp tới trong ngày hôm nay
  /// 2. Ca học sắp tới gần nhất trong ngày hôm nay
  /// 3. Hết ngày: Môn đầu tiên của ngày mai
  Session? getNextUpcomingSession(DateTime now) {
    final todaySessions = getTodaySessions(now);

    // 1. Lịch thi sắp tới trong ngày
    final upcomingExamsToday = todaySessions
        .where((s) =>
            s.kind == SessionKind.examSession &&
            s.calculateStatus(now) == SessionStatus.upcoming)
        .toList();
    if (upcomingExamsToday.isNotEmpty) {
      upcomingExamsToday.sort((a, b) => a.startMs.compareTo(b.startMs));
      return upcomingExamsToday.first;
    }

    // 2. Môn sắp tới gần nhất trong ngày
    final upcomingClassesToday = todaySessions
        .where((s) =>
            s.kind == SessionKind.classSession &&
            s.calculateStatus(now) == SessionStatus.upcoming)
        .toList();
    if (upcomingClassesToday.isNotEmpty) {
      upcomingClassesToday.sort((a, b) => a.startMs.compareTo(b.startMs));
      return upcomingClassesToday.first;
    }

    // 3. Môn đầu tiên của ngày mai
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowSessions = getSessionsForDate(tomorrow);
    if (tomorrowSessions.isNotEmpty) {
      final sortedTomorrow = List<Session>.from(tomorrowSessions)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      return sortedTomorrow.first;
    }

    // 4. Môn sắp tới bất kỳ trong tương lai
    final futureSessions = sessions
        .where((s) => s.start.isAfter(now))
        .toList();
    if (futureSessions.isNotEmpty) {
      futureSessions.sort((a, b) => a.startMs.compareTo(b.startMs));
      return futureSessions.first;
    }

    return null;
  }

  /// Lấy tất cả mốc đổi trạng thái trong ngày [date] (giờ bắt đầu, giờ kết thúc của từng môn, và 00:00 ngày hôm sau)
  /// Phục vụ cho TimelineProvider trên iOS và AlarmManager trên Android (Mục 4.3)
  List<DateTime> getAllEventTimestampsForDay(DateTime date) {
    final daySessions = getSessionsForDate(date);
    final set = <int>{};

    for (final s in daySessions) {
      set.add(s.startMs);
      set.add(s.endMs);
    }

    // Mốc 00:00 chuyển sang ngày hôm sau tại Việt Nam
    final nextMidnight = WidgetTimeUtils.nextVnMidnight(date);
    set.add(nextMidnight.millisecondsSinceEpoch);

    final list = set
        .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true))
        .toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }
}
