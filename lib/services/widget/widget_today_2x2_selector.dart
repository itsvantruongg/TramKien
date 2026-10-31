import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_time_utils.dart';
import 'widget_hash_utils.dart';

/// Trạng thái của Widget Hôm nay 2x2 theo Mục 3.1 & 3.6
enum Today2x2StateType {
  noSnapshot, // "Đăng nhập để xem lịch"
  emptyDay, // "Hôm nay không có lịch"
  allFinished, // "Hôm nay đã xong N môn"
  sessionActive, // Hiển thị ca học / ca thi
}

/// Dữ liệu đầu ra đã chuẩn hóa cho Widget Hôm nay 2x2
class Today2x2Data {
  final Today2x2StateType stateType;
  final String statusLabel; // "Đang học" / "Đang thi" / "Tiếp theo" / "Ngày mai" / ""
  final String subjectName;
  final String displayTitle; // Tên hiển thị tối đa 3 dòng cắt giữa "…" bảo tồn hậu tố (AC-09)
  final String subInfo; // "HH:mm · phòng" hoặc thông điệp phụ
  final bool showProgressBar; // Chỉ hiện khi đang học/thi và !endEstimated
  final double progress; // 0.0 .. 1.0
  final String? countdownAndroid; // "Đến HH:mm" (Android)
  final String? countdownIos; // "Còn N phút" (iOS)
  final bool isExam;
  final int colorIndex;
  final bool endEstimated;
  final Session? session;
  final String deepLinkUri; // tramkien://schedule?date=yyyy-MM-dd&sessionId=...

  const Today2x2Data({
    required this.stateType,
    required this.statusLabel,
    required this.subjectName,
    required this.displayTitle,
    required this.subInfo,
    this.showProgressBar = false,
    this.progress = 0.0,
    this.countdownAndroid,
    this.countdownIos,
    this.isExam = false,
    this.colorIndex = 0,
    this.endEstimated = false,
    this.session,
    required this.deepLinkUri,
  });

  bool get hasSession => stateType == Today2x2StateType.sessionActive && session != null;
}

/// Bộ chọn dữ liệu thuần cho Widget Hôm nay 2x2 (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.1)
class WidgetToday2x2Selector {
  /// Chọn phiên hiển thị cho Widget 2x2 tại mốc thời gian [now]
  /// Thứ tự ưu tiên (Mục 3.1):
  /// 1. Môn đang diễn ra (current) -> ưu tiên thi trước học, bắt đầu sớm trước
  /// 2. Lịch thi sắp tới trong ngày (kind == "exam" và upcoming)
  /// 3. Môn sắp tới gần nhất trong ngày (kind == "class" và upcoming)
  /// 4. Hết ngày: Môn đầu tiên của ngày mai (kèm nhãn "Ngày mai")
  /// 5. Trạng thái trống (mục 3.6): "Đăng nhập để xem lịch", "Hôm nay đã xong N môn", "Hôm nay không có lịch"
  static Today2x2Data select({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final nowIso = WidgetTimeUtils.formatVnDateIso(now);

    // 0. Chưa có bản chụp / bản chụp không hợp lệ
    if (snapshot == null || !snapshot.isValid) {
      return Today2x2Data(
        stateType: Today2x2StateType.noSnapshot,
        statusLabel: '',
        subjectName: 'Đăng nhập để xem lịch',
        displayTitle: 'Đăng nhập để xem lịch',
        subInfo: '',
        deepLinkUri: 'tramkien://schedule?date=$nowIso',
      );
    }

    final todaySessions = snapshot.getTodaySessions(now);

    // 1. Môn đang diễn ra (current)
    final activeSessions = todaySessions
        .where((s) => s.calculateStatus(now) == SessionStatus.current)
        .toList();
    if (activeSessions.isNotEmpty) {
      activeSessions.sort((a, b) {
        // Ưu tiên thi
        if (a.kind == SessionKind.examSession && b.kind != SessionKind.examSession) return -1;
        if (b.kind == SessionKind.examSession && a.kind != SessionKind.examSession) return 1;
        return a.startMs.compareTo(b.startMs);
      });

      final active = activeSessions.first;
      final isExam = active.kind == SessionKind.examSession;
      final statusLabel = isExam ? 'Đang thi' : 'Đang học';
      final showProgressAndCountdown = !active.endEstimated;
      final progress = showProgressAndCountdown ? active.calculateProgress(now) : 0.0;
      final endFormatted = WidgetTimeUtils.formatTimeHHmm(active.end);
      final remainingMinutes = active.getRemainingMinutes(now);

      return Today2x2Data(
        stateType: Today2x2StateType.sessionActive,
        statusLabel: statusLabel,
        subjectName: active.subjectName,
        displayTitle: _formatSubjectTitle(active.subjectName),
        subInfo: _formatSubInfo(active),
        showProgressBar: showProgressAndCountdown,
        progress: progress,
        countdownAndroid: showProgressAndCountdown ? 'Đến $endFormatted' : null,
        countdownIos: showProgressAndCountdown ? 'Còn $remainingMinutes phút' : null,
        isExam: isExam,
        colorIndex: active.colorIndex,
        endEstimated: active.endEstimated,
        session: active,
        deepLinkUri: _buildDeepLink(active),
      );
    }

    // 2. Lịch thi sắp tới trong ngày (kind == "exam" và upcoming)
    final upcomingExams = todaySessions
        .where((s) => s.kind == SessionKind.examSession && s.calculateStatus(now) == SessionStatus.upcoming)
        .toList();
    if (upcomingExams.isNotEmpty) {
      upcomingExams.sort((a, b) => a.startMs.compareTo(b.startMs));
      final exam = upcomingExams.first;
      return Today2x2Data(
        stateType: Today2x2StateType.sessionActive,
        statusLabel: 'Tiếp theo',
        subjectName: exam.subjectName,
        displayTitle: _formatSubjectTitle(exam.subjectName),
        subInfo: _formatSubInfo(exam),
        showProgressBar: false,
        isExam: true,
        colorIndex: exam.colorIndex,
        endEstimated: exam.endEstimated,
        session: exam,
        deepLinkUri: _buildDeepLink(exam),
      );
    }

    // 3. Môn sắp tới gần nhất trong ngày (kind == "class" và upcoming)
    final upcomingClasses = todaySessions
        .where((s) => s.kind == SessionKind.classSession && s.calculateStatus(now) == SessionStatus.upcoming)
        .toList();
    if (upcomingClasses.isNotEmpty) {
      upcomingClasses.sort((a, b) => a.startMs.compareTo(b.startMs));
      final nextClass = upcomingClasses.first;
      return Today2x2Data(
        stateType: Today2x2StateType.sessionActive,
        statusLabel: 'Tiếp theo',
        subjectName: nextClass.subjectName,
        displayTitle: _formatSubjectTitle(nextClass.subjectName),
        subInfo: _formatSubInfo(nextClass),
        showProgressBar: false,
        isExam: false,
        colorIndex: nextClass.colorIndex,
        endEstimated: nextClass.endEstimated,
        session: nextClass,
        deepLinkUri: _buildDeepLink(nextClass),
      );
    }

    // 4. Hết ngày: Môn đầu tiên của ngày mai (kèm nhãn "Ngày mai")
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowSessions = snapshot.getSessionsForDate(tomorrow);
    if (tomorrowSessions.isNotEmpty) {
      final sortedTomorrow = List<Session>.from(tomorrowSessions)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      final firstTomorrow = sortedTomorrow.first;
      return Today2x2Data(
        stateType: Today2x2StateType.sessionActive,
        statusLabel: 'Ngày mai',
        subjectName: firstTomorrow.subjectName,
        displayTitle: _formatSubjectTitle(firstTomorrow.subjectName),
        subInfo: _formatSubInfo(firstTomorrow),
        showProgressBar: false,
        isExam: firstTomorrow.kind == SessionKind.examSession,
        colorIndex: firstTomorrow.colorIndex,
        endEstimated: firstTomorrow.endEstimated,
        session: firstTomorrow,
        deepLinkUri: _buildDeepLink(firstTomorrow),
      );
    }

    // 5. Trạng thái trống (Mục 3.6):
    // Tìm môn học tiếp theo trong vòng 7 ngày tới
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

    // 5.1. Nếu hôm nay có môn và tất cả đều đã kết thúc
    if (todaySessions.isNotEmpty) {
      return Today2x2Data(
        stateType: Today2x2StateType.allFinished,
        statusLabel: '',
        subjectName: 'Hôm nay đã xong ${todaySessions.length} môn',
        displayTitle: 'Hôm nay đã xong ${todaySessions.length} môn',
        subInfo: nextPreviewText,
        deepLinkUri: 'tramkien://schedule?date=$nowIso',
      );
    }

    // 5.2. Hôm nay không có môn nào được xếp
    return Today2x2Data(
      stateType: Today2x2StateType.emptyDay,
      statusLabel: '',
      subjectName: 'Hôm nay không có lịch',
      displayTitle: 'Hôm nay không có lịch',
      subInfo: nextPreviewText,
      deepLinkUri: 'tramkien://schedule?date=$nowIso',
    );
  }

  /// Tính mốc đổi trạng thái kế tiếp (phục vụ AlarmManager trên Android & reload timeline)
  static DateTime getNextTransitionTime({
    required WidgetScheduleSnapshot snapshot,
    required DateTime now,
  }) {
    final nowMs = now.millisecondsSinceEpoch;
    final today = snapshot.getTodaySessions(now);

    final eventTimestamps = <int>{};
    for (final s in today) {
      if (s.startMs > nowMs) eventTimestamps.add(s.startMs);
      if (s.endMs > nowMs) eventTimestamps.add(s.endMs);
    }

    // Luôn bao gồm mốc chuyển ngày 00:00 Việt Nam
    final nextMidnight = WidgetTimeUtils.nextVnMidnight(now);
    eventTimestamps.add(nextMidnight.millisecondsSinceEpoch);

    final sorted = eventTimestamps.toList()..sort();
    final nextMs = sorted.firstWhere((ms) => ms > nowMs, orElse: () => nextMidnight.millisecondsSinceEpoch);
    return DateTime.fromMillisecondsSinceEpoch(nextMs, isUtc: true);
  }

  /// Lấy toàn bộ mốc đổi trạng thái trong ngày [date] (giờ bắt đầu, giờ kết thúc của từng môn, và 00:00 ngày hôm sau)
  static List<DateTime> getAllDayTransitionTimes({
    required WidgetScheduleSnapshot snapshot,
    required DateTime date,
  }) {
    return snapshot.getAllEventTimestampsForDay(date);
  }

  static String _formatSubjectTitle(String subjectName) {
    // Tối đa 40 ký tự trên widget 2x2, cắt giữa bảo tồn hậu tố (AC-09)
    return WidgetHashUtils.formatWithEllipsisPreservation(subjectName, maxLength: 40);
  }

  static String _formatSubInfo(Session s) {
    final startFormatted = WidgetTimeUtils.formatTimeHHmm(s.start);
    if (s.room.trim().isNotEmpty) {
      return '$startFormatted · ${s.room.trim()}';
    }
    return startFormatted;
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
}
