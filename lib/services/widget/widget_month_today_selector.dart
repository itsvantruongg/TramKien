import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_time_utils.dart';
import 'widget_today_2x2_selector.dart';

/// Dữ liệu của 1 ô ngày trong lưới tháng (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.2)
class MonthGridDay {
  final int day; // 1..31
  final int month;
  final int year;
  final bool isToday;
  final bool hasClasses;
  final bool hasExam;
  final String deepLinkUri;

  const MonthGridDay({
    required this.day,
    required this.month,
    required this.year,
    required this.isToday,
    required this.hasClasses,
    required this.hasExam,
    required this.deepLinkUri,
  });

  bool get hasSchedule => hasClasses || hasExam;

  /// Chấm học màu phụ (chỉ khi có môn học, không có thi, và không phải hôm nay)
  bool get showStudyDot => hasClasses && !hasExam && !isToday;

  /// Chấm đỏ thi (khi có thi, bất kể ngày thường hay hôm nay)
  bool get showExamDot => hasExam;
}

/// Dữ liệu toàn bộ lưới tháng
class MonthGridData {
  final int year;
  final int month;
  final int monthOffset;
  final String monthTitle; // "Tháng M/YYYY"
  final List<String> weekdayHeaders; // ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
  final List<MonthGridDay?> cells; // 35 hoặc 42 ô (7 cột x 5..6 hàng)
  final List<List<MonthGridDay?>> rows;

  const MonthGridData({
    required this.year,
    required this.month,
    required this.monthOffset,
    required this.monthTitle,
    required this.weekdayHeaders,
    required this.cells,
    required this.rows,
  });
}

/// Thẻ môn hôm nay (nửa phải)
class MonthTodayCardItem {
  final Session session;
  final String timeRoomLine; // "HH:mm · phòng" hoặc "HH:mm · phòng · Thi"
  final String displayTitle; // Tên môn 1 dòng cắt "…" bảo tồn hậu tố
  final bool isExam;
  final bool isCurrent;
  final int colorIndex;
  final String deepLinkUri;

  const MonthTodayCardItem({
    required this.session,
    required this.timeRoomLine,
    required this.displayTitle,
    required this.isExam,
    required this.isCurrent,
    required this.colorIndex,
    required this.deepLinkUri,
  });
}

/// Dữ liệu nửa phải: Lịch hôm nay
class TodayScheduleData {
  final Today2x2StateType stateType;
  final String headerLeft; // "Thứ, dd/MM" (ví dụ: "T4, 28/10")
  final String headerRight; // "N môn" (ví dụ: "4 môn")
  final int totalSessionsToday;
  final List<MonthTodayCardItem> visibleCards; // Tối đa 2 thẻ
  final int overflowCount; // N môn chưa hiển thị
  final String? overflowLabel; // "+N môn nữa" nếu N > 0, ngược lại null
  final String? emptyTitle;
  final String? emptySubtitle;
  final String deepLinkUri;

  const TodayScheduleData({
    required this.stateType,
    required this.headerLeft,
    required this.headerRight,
    required this.totalSessionsToday,
    required this.visibleCards,
    this.overflowCount = 0,
    this.overflowLabel,
    this.emptyTitle,
    this.emptySubtitle,
    required this.deepLinkUri,
  });
}

/// Dữ liệu hợp nhất cho Widget Tháng + Hôm nay 4x2
class MonthToday4x2Data {
  final MonthGridData monthGrid;
  final TodayScheduleData todaySchedule;

  const MonthToday4x2Data({
    required this.monthGrid,
    required this.todaySchedule,
  });
}

/// Bộ chọn dữ liệu thuần cho Widget Tháng + Hôm nay 4x2
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.2, 3.5, 3.6, 7
class WidgetMonthTodaySelector {
  static const List<String> kWeekdayHeaders = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  /// Chọn toàn bộ dữ liệu cho Widget Tháng + Hôm nay (4x2)
  static MonthToday4x2Data select({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
    int monthOffset = 0,
  }) {
    final monthGrid = selectMonthGrid(
      snapshot: snapshot,
      now: now,
      monthOffset: monthOffset,
    );
    final todaySchedule = selectTodaySchedule(
      snapshot: snapshot,
      now: now,
    );

    return MonthToday4x2Data(
      monthGrid: monthGrid,
      todaySchedule: todaySchedule,
    );
  }

  /// Tính toán lưới lịch tháng (Nửa trái)
  static MonthGridData selectMonthGrid({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
    int monthOffset = 0,
  }) {
    final nowVn = WidgetTimeUtils.toVnDateTime(now);

    // Tính tháng mục tiêu dựa theo monthOffset
    var targetYear = nowVn.year;
    var targetMonth = nowVn.month + monthOffset;
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear += 1;
    }
    while (targetMonth < 1) {
      targetMonth += 12;
      targetYear -= 1;
    }

    final monthTitle = 'Tháng $targetMonth/$targetYear';

    // Ngày 1 của tháng mục tiêu
    final firstDayDate = DateTime.utc(targetYear, targetMonth, 1);
    // Weekday: 1 (T2) -> 7 (CN)
    final firstDayWeekday = firstDayDate.weekday;
    final emptyLeadingCount = firstDayWeekday - 1;

    // Tổng số ngày trong tháng
    final daysInMonth = DateTime.utc(targetYear, targetMonth + 1, 0).day;

    final List<MonthGridDay?> cells = [];

    // Ô trống đầu tháng
    for (var i = 0; i < emptyLeadingCount; i++) {
      cells.add(null);
    }

    // Các ngày trong tháng
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = (targetYear == nowVn.year &&
          targetMonth == nowVn.month &&
          d == nowVn.day);

      final dateIso =
          '${targetYear.toString().padLeft(4, '0')}-${targetMonth.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

      bool hasClasses = false;
      bool hasExam = false;

      if (snapshot != null && snapshot.isValid) {
        final sessionsOnDay = snapshot.sessions.where((s) {
          final vnStart = WidgetTimeUtils.toVnDateTime(s.start);
          return vnStart.year == targetYear &&
              vnStart.month == targetMonth &&
              vnStart.day == d;
        });

        for (final s in sessionsOnDay) {
          if (s.kind == SessionKind.examSession) {
            hasExam = true;
          } else {
            hasClasses = true;
          }
        }
      }

      cells.add(MonthGridDay(
        day: d,
        month: targetMonth,
        year: targetYear,
        isToday: isToday,
        hasClasses: hasClasses,
        hasExam: hasExam,
        deepLinkUri: 'tramkien://schedule?date=$dateIso',
      ));
    }

    // Làm tròn hàng 7 cột
    final remainingInRow = cells.length % 7;
    if (remainingInRow > 0) {
      final trailingEmpty = 7 - remainingInRow;
      for (var i = 0; i < trailingEmpty; i++) {
        cells.add(null);
      }
    }

    // Chia thành các hàng 7 ô
    final List<List<MonthGridDay?>> rows = [];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return MonthGridData(
      year: targetYear,
      month: targetMonth,
      monthOffset: monthOffset,
      monthTitle: monthTitle,
      weekdayHeaders: kWeekdayHeaders,
      cells: cells,
      rows: rows,
    );
  }

  /// Tính toán lịch hôm nay (Nửa phải)
  static TodayScheduleData selectTodaySchedule({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final nowIso = WidgetTimeUtils.formatVnDateIso(now);
    final headerLeft =
        '${WidgetTimeUtils.formatWeekdayAbbr(now)}, ${WidgetTimeUtils.formatVnDateDdMm(now)}';

    // 0. Chưa có bản chụp / bản chụp lỗi
    if (snapshot == null || !snapshot.isValid) {
      return TodayScheduleData(
        stateType: Today2x2StateType.noSnapshot,
        headerLeft: headerLeft,
        headerRight: '0 môn',
        totalSessionsToday: 0,
        visibleCards: const [],
        overflowCount: 0,
        overflowLabel: null,
        emptyTitle: 'Đăng nhập để xem lịch',
        emptySubtitle: '',
        deepLinkUri: 'tramkien://schedule?date=$nowIso',
      );
    }

    final todaySessions = snapshot.getTodaySessions(now);
    final totalCount = todaySessions.length;
    final headerRight = '$totalCount môn';

    // Lọc các ca chưa kết thúc trong ngày (status != past)
    final remainingSessions = todaySessions
        .where((s) => s.calculateStatus(now) != SessionStatus.past)
        .toList();
    remainingSessions.sort((a, b) => a.startMs.compareTo(b.startMs));

    // Nếu không còn môn nào chưa kết thúc
    if (remainingSessions.isEmpty) {
      final deadlineMs = now.millisecondsSinceEpoch + 7 * 86400 * 1000;
      final futureSessions = snapshot.sessions
          .where((s) =>
              s.startMs > now.millisecondsSinceEpoch && s.startMs <= deadlineMs)
          .toList();
      futureSessions.sort((a, b) => a.startMs.compareTo(b.startMs));

      String nextPreview;
      if (futureSessions.isNotEmpty) {
        final next = futureSessions.first;
        final nextThu = WidgetTimeUtils.formatWeekdayAbbr(next.start);
        final nextTime = WidgetTimeUtils.formatTimeHHmm(next.start);
        final nextName = next.shortName.isNotEmpty ? next.shortName : next.subjectName;
        nextPreview = 'Tiếp theo: $nextThu $nextTime $nextName';
      } else {
        nextPreview = 'Không có lịch sắp tới';
      }

      if (todaySessions.isEmpty) {
        return TodayScheduleData(
          stateType: Today2x2StateType.emptyDay,
          headerLeft: headerLeft,
          headerRight: headerRight,
          totalSessionsToday: 0,
          visibleCards: const [],
          overflowCount: 0,
          overflowLabel: null,
          emptyTitle: 'Hôm nay không có lịch',
          emptySubtitle: nextPreview,
          deepLinkUri: 'tramkien://schedule?date=$nowIso',
        );
      } else {
        return TodayScheduleData(
          stateType: Today2x2StateType.allFinished,
          headerLeft: headerLeft,
          headerRight: headerRight,
          totalSessionsToday: totalCount,
          visibleCards: const [],
          overflowCount: 0,
          overflowLabel: null,
          emptyTitle: 'Hôm nay đã xong $totalCount môn',
          emptySubtitle: nextPreview,
          deepLinkUri: 'tramkien://schedule?date=$nowIso',
        );
      }
    }

    // Áp dụng QUY TẮC ƯU TIÊN LỊCH THI (AC-11) cho tối đa 2 thẻ:
    // Lịch thi chưa diễn ra trong ngày LUÔN ĐƯỢC ƯU TIÊN đưa vào 1 trong 2 vị trí hiển thị.
    final exams = remainingSessions
        .where((s) => s.kind == SessionKind.examSession)
        .toList();
    final nonExams = remainingSessions
        .where((s) => s.kind != SessionKind.examSession)
        .toList();

    List<Session> chosenSessions = [];

    if (exams.length >= 2) {
      // 2 môn thi chiếm 2 vị trí
      chosenSessions = exams.take(2).toList();
    } else if (exams.length == 1) {
      // 1 môn thi được ưu tiên vị trí 1
      chosenSessions = [exams.first];
      // Vị trí 2 dành cho môn thường sớm nhất chưa qua
      if (nonExams.isNotEmpty) {
        chosenSessions.add(nonExams.first);
      }
      // Sắp xếp lại theo thời gian bắt đầu thực tế để hiển thị tự nhiên
      chosenSessions.sort((a, b) => a.startMs.compareTo(b.startMs));
    } else {
      // Không có môn thi -> lấy 2 môn học sớm nhất
      chosenSessions = nonExams.take(2).toList();
    }

    final visibleCards = chosenSessions.map((s) {
      final isExam = s.kind == SessionKind.examSession;
      final isCurrent = s.calculateStatus(now) == SessionStatus.current;
      final startStr = WidgetTimeUtils.formatTimeHHmm(s.start);
      final roomStr = s.room.isNotEmpty ? s.room : 'Chưa có phòng';

      final timeRoomLine = isExam
          ? '$startStr · $roomStr · Thi'
          : '$startStr · $roomStr';

      final displayTitle = formatWithEllipsisPreservation(s.subjectName, maxLength: 36);

      final sessionIso = WidgetTimeUtils.formatVnDateIso(s.start);
      final deepLink = 'tramkien://schedule?date=$sessionIso&sessionId=${s.id}';

      return MonthTodayCardItem(
        session: s,
        timeRoomLine: timeRoomLine,
        displayTitle: displayTitle,
        isExam: isExam,
        isCurrent: isCurrent,
        colorIndex: s.colorIndex,
        deepLinkUri: deepLink,
      );
    }).toList();

    // Số môn còn lại chưa hiển thị (+N môn nữa)
    final overflow = remainingSessions.length - chosenSessions.length;
    final overflowCount = overflow > 0 ? overflow : 0;
    final overflowLabel = overflowCount > 0 ? '+$overflowCount môn nữa' : null;

    return TodayScheduleData(
      stateType: Today2x2StateType.sessionActive,
      headerLeft: headerLeft,
      headerRight: headerRight,
      totalSessionsToday: totalCount,
      visibleCards: visibleCards,
      overflowCount: overflowCount,
      overflowLabel: overflowLabel,
      deepLinkUri: 'tramkien://schedule?date=$nowIso',
    );
  }

  /// Quy tắc cắt tên dài bảo tồn hậu tố (Ellipsis Preservation - AC-09)
  static String formatWithEllipsisPreservation(String name, {int maxLength = 36}) {
    final trimmed = name.trim();
    if (trimmed.length <= maxLength) return trimmed;

    // Kiểm tra hậu tố phân biệt (số hoặc chữ số La Mã hoặc ký tự đơn)
    final suffixMatch =
        RegExp(r'(\s+(?:[0-9]+|[IVXLCDM]+|[A-Za-z]))$').firstMatch(trimmed);

    if (suffixMatch != null) {
      final suffix = suffixMatch.group(1)!;
      final budget = maxLength - 1 - suffix.length; // trừ 1 cho ký tự '…'

      if (budget >= 6) {
        final leftBudget = (budget * 0.55).toInt();
        final rightBudget = budget - leftBudget;

        final leftPart = trimmed.substring(0, leftBudget).trimRight();
        final beforeSuffix = trimmed.substring(0, suffixMatch.start);
        final rightStart = beforeSuffix.length - rightBudget;
        final rightPart = rightStart > leftBudget
            ? beforeSuffix.substring(rightStart).trimLeft()
            : '';

        if (rightPart.isNotEmpty) {
          return '$leftPart…$rightPart$suffix';
        } else {
          return '$leftPart…$suffix';
        }
      }
    }

    return '${trimmed.substring(0, (maxLength - 1).clamp(1, trimmed.length)).trimRight()}…';
  }

  /// Tính mốc thời gian tiếp theo cần cập nhật trạng thái
  static DateTime getNextTransitionTime({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final midnight = WidgetTimeUtils.nextVnMidnight(now);
    if (snapshot == null || !snapshot.isValid) {
      return midnight;
    }

    final nowMs = now.millisecondsSinceEpoch;
    int? nextMs;

    for (final s in snapshot.sessions) {
      if (s.startMs > nowMs) {
        if (nextMs == null || s.startMs < nextMs) {
          nextMs = s.startMs;
        }
      }
      if (s.endMs > nowMs) {
        if (nextMs == null || s.endMs < nextMs) {
          nextMs = s.endMs;
        }
      }
    }

    final midnightMs = midnight.millisecondsSinceEpoch;
    if (nextMs == null || midnightMs < nextMs) {
      return midnight;
    }

    return DateTime.fromMillisecondsSinceEpoch(nextMs, isUtc: true);
  }

  /// Lấy toàn bộ các mốc thay đổi trạng thái trong ngày cho TimelineProvider
  static List<DateTime> getAllDayTransitionTimes({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    final results = <DateTime>{now};
    final midnight = WidgetTimeUtils.nextVnMidnight(now);
    results.add(midnight);

    if (snapshot != null && snapshot.isValid) {
      final todaySessions = snapshot.getTodaySessions(now);
      final nowMs = now.millisecondsSinceEpoch;

      for (final s in todaySessions) {
        if (s.startMs > nowMs) {
          results.add(DateTime.fromMillisecondsSinceEpoch(s.startMs, isUtc: true));
        }
        if (s.endMs > nowMs) {
          results.add(DateTime.fromMillisecondsSinceEpoch(s.endMs, isUtc: true));
        }
      }
    }

    final list = results.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }
}
