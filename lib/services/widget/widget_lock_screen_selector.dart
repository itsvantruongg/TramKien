import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_time_utils.dart';
import 'widget_hash_utils.dart';

/// Trạng thái của Widget Màn hình khóa (Lock Screen) theo Mục 3.5 & 3.6
enum LockScreenStateType {
  noSnapshot, // "Đăng nhập để xem lịch"
  emptyDay, // "Hôm nay không có lịch"
  allFinished, // "Hôm nay đã xong N môn"
  sessionActive, // Có ca học / ca thi
}

/// Dữ liệu đầu ra cho widget accessoryRectangular (~160x58 dp/pt)
class LockScreenRectangularData {
  final LockScreenStateType stateType;
  final String line1; // "Đang học · HH:mm" / "Đang thi · HH:mm" / "Tiếp theo · HH:mm" / "Hôm nay không có lịch" / "Đăng nhập để xem lịch"
  final String line2; // Tên môn học (1 dòng, cắt "…" hoặc shortName) / preview môn kế tiếp
  final String? line3; // "phòng · còn N phút" (null nếu ca thi endEstimated = true hoặc khi không có lịch)
  final bool isExam;
  final bool endEstimated;
  final Session? session;
  final String deepLinkUri;

  const LockScreenRectangularData({
    required this.stateType,
    required this.line1,
    required this.line2,
    this.line3,
    this.isExam = false,
    this.endEstimated = false,
    this.session,
    required this.deepLinkUri,
  });

  bool get hasSession => stateType == LockScreenStateType.sessionActive && session != null;
}

/// Dữ liệu đầu ra cho widget accessoryCircular (Đường kính ~60-70 dp/pt)
class LockScreenCircularData {
  final String centerText; // Giờ bắt đầu môn kế tiếp (định dạng HH:mm) hoặc môn ngày mai hoặc "--:--"
  final double progress; // 0.0 .. 1.0 (rỗng nếu không có môn đang học hoặc ca thi endEstimated = true)
  final bool hasActiveSession;
  final Session? activeSession;
  final Session? nextSession;
  final String deepLinkUri;

  const LockScreenCircularData({
    required this.centerText,
    required this.progress,
    this.hasActiveSession = false,
    this.activeSession,
    this.nextSession,
    required this.deepLinkUri,
  });
}

/// Dữ liệu đầu ra cho widget accessoryInline (1 dòng duy nhất)
class LockScreenInlineData {
  final String text; // "HH:mm ShortName · phòng" hoặc "Không có lịch hôm nay" hoặc "Đăng nhập để xem lịch"
  final Session? session;
  final String deepLinkUri;

  const LockScreenInlineData({
    required this.text,
    this.session,
    required this.deepLinkUri,
  });
}

/// Dữ liệu tổng hợp cho toàn bộ các Widget Màn hình khóa
class LockScreenData {
  final LockScreenRectangularData rectangular;
  final LockScreenCircularData circular;
  final LockScreenInlineData inline;
  final DateTime now;

  const LockScreenData({
    required this.rectangular,
    required this.circular,
    required this.inline,
    required this.now,
  });
}

/// Bộ chọn dữ liệu thuần cho Widget Màn hình khóa (Lock Screen) iOS & Android
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.5 & 3.6
class WidgetLockScreenSelector {
  /// Rút gọn phòng học cho widget màn hình khóa
  static String simplifyRoom(String rawRoom) {
    var room = rawRoom.trim();
    if (room.isEmpty) return '';
    room = room.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    room = room.replaceAllMapped(RegExp(r'^[Pp]\.([A-Za-z0-9]+)'), (m) => 'P${m[1]}');
    return room.trim();
  }

  /// Tính toán dữ liệu tổng hợp cho cả 3 widget Lock Screen tại mốc [now]
  static LockScreenData select({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    return LockScreenData(
      rectangular: selectRectangular(snapshot: snapshot, now: now),
      circular: selectCircular(snapshot: snapshot, now: now),
      inline: selectInline(snapshot: snapshot, now: now),
      now: now,
    );
  }

  /// 1. Bộ chọn cho accessoryRectangular (~160x58 dp/pt)
  /// - Dòng 1: "Đang học · HH:mm" / "Đang thi · HH:mm" / "Tiếp theo · HH:mm"
  /// - Dòng 2: Tên môn học (1 dòng, cắt "…")
  /// - Dòng 3: "phòng · còn N phút"
  ///   QUY TẮC ĐẶC BIỆT: Với ca thi có endEstimated = true: Chỉ hiển thị Dòng 1 "Đang thi · HH:mm" và Dòng 2 tên môn, BỎ DÒNG "còn N phút".
  /// - Khi không có lịch: "Hôm nay không có lịch" / "Tiếp theo: <thứ> HH:mm <tên môn>" hoặc "Đăng nhập để xem lịch".
  static LockScreenRectangularData selectRectangular({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final nowIso = WidgetTimeUtils.formatVnDateIso(now);
    final fallbackDeepLink = 'tramkien://schedule?date=$nowIso';

    // 0. Chưa có bản chụp / không hợp lệ
    if (snapshot == null || !snapshot.isValid) {
      return LockScreenRectangularData(
        stateType: LockScreenStateType.noSnapshot,
        line1: 'Đăng nhập để xem lịch',
        line2: '',
        line3: null,
        deepLinkUri: fallbackDeepLink,
      );
    }

    final todaySessions = snapshot.getTodaySessions(now);

    // 1. Môn đang diễn ra (current)
    final activeSessions = todaySessions
        .where((s) => s.calculateStatus(now) == SessionStatus.current)
        .toList();

    if (activeSessions.isNotEmpty) {
      activeSessions.sort((a, b) {
        if (a.kind == SessionKind.examSession && b.kind != SessionKind.examSession) return -1;
        if (b.kind == SessionKind.examSession && a.kind != SessionKind.examSession) return 1;
        return a.startMs.compareTo(b.startMs);
      });

      final active = activeSessions.first;
      final isExam = active.kind == SessionKind.examSession;
      final startHHmm = WidgetTimeUtils.formatTimeHHmm(active.start);
      final line1 = isExam ? 'Đang thi · $startHHmm' : 'Đang học · $startHHmm';
      final line2 = active.shortName.isNotEmpty
          ? active.shortName
          : WidgetHashUtils.formatWithEllipsisPreservation(active.subjectName, maxLength: 24);

      String? line3;
      if (isExam && active.endEstimated) {
        // QUY TẮC ĐẶC BIỆT: Với ca thi có endEstimated = true: bỏ dòng 3 "còn N phút"
        line3 = null;
      } else {
        final remaining = active.getRemainingMinutes(now);
        final room = simplifyRoom(active.room);
        line3 = room.isNotEmpty ? '$room · còn $remaining phút' : 'còn $remaining phút';
      }

      return LockScreenRectangularData(
        stateType: LockScreenStateType.sessionActive,
        line1: line1,
        line2: line2,
        line3: line3,
        isExam: isExam,
        endEstimated: active.endEstimated,
        session: active,
        deepLinkUri: _buildDeepLink(active),
      );
    }

    // 2. Môn sắp tới trong ngày (upcoming)
    // Ưu tiên lịch thi sắp tới, sau đó đến môn học sớm nhất
    final upcomingExams = todaySessions
        .where((s) => s.kind == SessionKind.examSession && s.calculateStatus(now) == SessionStatus.upcoming)
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final upcomingClasses = todaySessions
        .where((s) => s.kind == SessionKind.classSession && s.calculateStatus(now) == SessionStatus.upcoming)
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final Session? nextSession = upcomingExams.isNotEmpty
        ? upcomingExams.first
        : (upcomingClasses.isNotEmpty ? upcomingClasses.first : null);

    if (nextSession != null) {
      final startHHmm = WidgetTimeUtils.formatTimeHHmm(nextSession.start);
      final line1 = 'Tiếp theo · $startHHmm';
      final line2 = nextSession.shortName.isNotEmpty
          ? nextSession.shortName
          : WidgetHashUtils.formatWithEllipsisPreservation(nextSession.subjectName, maxLength: 24);
      final minutesUntil = nextSession.start.difference(now).inMinutes;
      final room = simplifyRoom(nextSession.room);
      final line3 = room.isNotEmpty ? '$room · còn $minutesUntil phút' : 'còn $minutesUntil phút';

      return LockScreenRectangularData(
        stateType: LockScreenStateType.sessionActive,
        line1: line1,
        line2: line2,
        line3: line3,
        isExam: nextSession.kind == SessionKind.examSession,
        endEstimated: nextSession.endEstimated,
        session: nextSession,
        deepLinkUri: _buildDeepLink(nextSession),
      );
    }

    // 3. Không còn ca nào trong hôm nay (Trạng thái trống)
    final nextSessionWithin7Days = _findNextSessionWithinDays(snapshot, now, 7);
    final String nextPreviewText;
    if (nextSessionWithin7Days != null) {
      final weekday = WidgetTimeUtils.formatWeekdayAbbr(nextSessionWithin7Days.start);
      final timeStr = WidgetTimeUtils.formatTimeHHmm(nextSessionWithin7Days.start);
      final nameStr = nextSessionWithin7Days.shortName.isNotEmpty
          ? nextSessionWithin7Days.shortName
          : nextSessionWithin7Days.subjectName;
      nextPreviewText = 'Tiếp theo: $weekday $timeStr $nameStr';
    } else {
      nextPreviewText = 'Không có lịch sắp tới';
    }

    if (todaySessions.isNotEmpty) {
      // Đã xong toàn bộ ca trong ngày
      return LockScreenRectangularData(
        stateType: LockScreenStateType.allFinished,
        line1: 'Hôm nay đã xong ${todaySessions.length} môn',
        line2: nextPreviewText,
        line3: null,
        deepLinkUri: fallbackDeepLink,
      );
    }

    // Hôm nay không có môn nào
    return LockScreenRectangularData(
      stateType: LockScreenStateType.emptyDay,
      line1: 'Hôm nay không có lịch',
      line2: nextPreviewText,
      line3: null,
      deepLinkUri: fallbackDeepLink,
    );
  }

  /// 2. Bộ chọn cho accessoryCircular
  /// - Chữ ở giữa: Giờ bắt đầu môn kế tiếp (định dạng HH:mm).
  /// - Vòng cung Gauge / ProgressView: Hiển thị tiến độ môn đang học (0.0..1.0). Rỗng (0.0) nếu không có môn đang học hoặc ca thi có endEstimated = true.
  /// - Khi không có môn kế tiếp trong ngày: Giờ bắt đầu môn ngày mai (nếu có) hoặc icon lịch/dấu gạch.
  static LockScreenCircularData selectCircular({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final nowIso = WidgetTimeUtils.formatVnDateIso(now);
    final fallbackDeepLink = 'tramkien://schedule?date=$nowIso';

    if (snapshot == null || !snapshot.isValid) {
      return LockScreenCircularData(
        centerText: '--:--',
        progress: 0.0,
        hasActiveSession: false,
        deepLinkUri: fallbackDeepLink,
      );
    }

    final todaySessions = snapshot.getTodaySessions(now);
    final nowMs = now.millisecondsSinceEpoch;

    // Môn đang diễn ra (current)
    final activeSessions = todaySessions
        .where((s) => s.calculateStatus(now) == SessionStatus.current)
        .toList();

    double progress = 0.0;
    Session? active;

    if (activeSessions.isNotEmpty) {
      activeSessions.sort((a, b) {
        if (a.kind == SessionKind.examSession && b.kind != SessionKind.examSession) return -1;
        if (b.kind == SessionKind.examSession && a.kind != SessionKind.examSession) return 1;
        return a.startMs.compareTo(b.startMs);
      });
      active = activeSessions.first;

      // Rỗng nếu ca thi có endEstimated = true
      if (active.kind == SessionKind.examSession && active.endEstimated) {
        progress = 0.0;
      } else {
        progress = active.calculateProgress(now).clamp(0.0, 1.0);
      }
    }

    // Tìm môn kế tiếp (upcoming)
    // 1. Tìm trong ngày hôm nay bắt đầu sau now
    final upcomingToday = todaySessions
        .where((s) => s.startMs > nowMs)
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    String centerText;
    Session? nextSession;

    if (upcomingToday.isNotEmpty) {
      nextSession = upcomingToday.first;
      centerText = WidgetTimeUtils.formatTimeHHmm(nextSession.start);
    } else {
      // 2. Không có môn kế tiếp trong ngày: Giờ bắt đầu môn ngày mai (nếu có)
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowSessions = snapshot.getSessionsForDate(tomorrow);
      if (tomorrowSessions.isNotEmpty) {
        final sortedTomorrow = List<Session>.from(tomorrowSessions)
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
        nextSession = sortedTomorrow.first;
        centerText = WidgetTimeUtils.formatTimeHHmm(nextSession.start);
      } else {
        centerText = '--:--';
      }
    }

    return LockScreenCircularData(
      centerText: centerText,
      progress: progress,
      hasActiveSession: active != null,
      activeSession: active,
      nextSession: nextSession,
      deepLinkUri: active != null ? _buildDeepLink(active) : fallbackDeepLink,
    );
  }

  /// 3. Bộ chọn cho accessoryInline (1 dòng duy nhất)
  /// - Định dạng: "HH:mm ShortName · phòng" (dùng shortName).
  /// - Khi trống: "Không có lịch hôm nay" hoặc "Đăng nhập để xem lịch".
  static LockScreenInlineData selectInline({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final nowIso = WidgetTimeUtils.formatVnDateIso(now);
    final fallbackDeepLink = 'tramkien://schedule?date=$nowIso';

    if (snapshot == null || !snapshot.isValid) {
      return LockScreenInlineData(
        text: 'Đăng nhập để xem lịch',
        deepLinkUri: fallbackDeepLink,
      );
    }

    final todaySessions = snapshot.getTodaySessions(now);
    final nowMs = now.millisecondsSinceEpoch;

    // 1. Nếu có môn đang diễn ra (current), ưu tiên hiển thị môn đang diễn ra
    final activeSessions = todaySessions
        .where((s) => s.calculateStatus(now) == SessionStatus.current)
        .toList();

    if (activeSessions.isNotEmpty) {
      activeSessions.sort((a, b) {
        if (a.kind == SessionKind.examSession && b.kind != SessionKind.examSession) return -1;
        if (b.kind == SessionKind.examSession && a.kind != SessionKind.examSession) return 1;
        return a.startMs.compareTo(b.startMs);
      });
      final active = activeSessions.first;
      return LockScreenInlineData(
        text: _formatInlineSession(active),
        session: active,
        deepLinkUri: _buildDeepLink(active),
      );
    }

    // 2. Nếu không có môn đang diễn ra, tìm môn kế tiếp trong ngày hôm nay
    final upcomingToday = todaySessions
        .where((s) => s.startMs > nowMs)
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    if (upcomingToday.isNotEmpty) {
      final next = upcomingToday.first;
      return LockScreenInlineData(
        text: _formatInlineSession(next),
        session: next,
        deepLinkUri: _buildDeepLink(next),
      );
    }

    // 3. Khi trống / hết ngày: "Không có lịch hôm nay"
    return LockScreenInlineData(
      text: 'Không có lịch hôm nay',
      deepLinkUri: fallbackDeepLink,
    );
  }

  static String _formatInlineSession(Session session) {
    final startHHmm = WidgetTimeUtils.formatTimeHHmm(session.start);
    final shortName = session.shortName.isNotEmpty ? session.shortName : session.subjectName;
    final room = simplifyRoom(session.room);
    if (room.isNotEmpty) {
      return '$startHHmm $shortName · $room';
    }
    return '$startHHmm $shortName';
  }

  static String _buildDeepLink(Session s) {
    final dateIso = WidgetTimeUtils.formatVnDateIso(s.start);
    return 'tramkien://schedule?date=$dateIso&sessionId=${s.id}';
  }

  static Session? _findNextSessionWithinDays(WidgetScheduleSnapshot snapshot, DateTime now, int days) {
    final deadline = now.add(Duration(days: days));
    final futureSessions = snapshot.sessions
        .where((s) => s.start.isAfter(now) && !s.start.isAfter(deadline))
        .toList();

    if (futureSessions.isEmpty) return null;
    futureSessions.sort((a, b) => a.startMs.compareTo(b.startMs));
    return futureSessions.first;
  }

  /// Lấy toàn bộ mốc đổi trạng thái trong ngày [date] cho Lock Screen entries
  static List<DateTime> getAllDayTransitionTimes({
    required WidgetScheduleSnapshot snapshot,
    required DateTime date,
  }) {
    return snapshot.getAllEventTimestampsForDay(date);
  }
}
