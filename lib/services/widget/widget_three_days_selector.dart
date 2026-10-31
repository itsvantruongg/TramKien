import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_time_utils.dart';
import 'widget_hash_utils.dart';

/// Thẻ môn trong cột 3 ngày (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.3)
class ThreeDaysCardItem {
  final Session session;
  final String timeStr; // "HH:mm"
  final String roomStr; // Phòng viết gọn, ví dụ "P102", "B205"
  final String timeRoomLine; // "HH:mm · phòng" (hoặc "HH:mm" nếu không có phòng)
  final String shortName; // Tên rút gọn 1 dòng
  final String displayTitle;
  final bool isExam;
  final bool isCurrent;
  final int colorIndex;
  final String deepLinkUri;

  const ThreeDaysCardItem({
    required this.session,
    required this.timeStr,
    required this.roomStr,
    required this.timeRoomLine,
    required this.shortName,
    required this.displayTitle,
    required this.isExam,
    required this.isCurrent,
    required this.colorIndex,
    required this.deepLinkUri,
  });
}

/// Dữ liệu cho 1 cột ngày trong Widget 3 ngày (Hôm nay, Ngày mai, Ngày kia)
class ThreeDaysColumnData {
  final DateTime date;
  final String dateIso; // "yyyy-MM-dd"
  final String title; // "Hôm nay dd" cho hôm nay, "Thứ · dd" cho ngày khác
  final bool isToday;
  final List<ThreeDaysCardItem> visibleCards; // Tối đa 2 thẻ
  final int hiddenCount; // Số môn bị ẩn
  final String? badgeText; // "+N" khi N > 0, null khi N = 0
  final bool isEmpty; // true khi không có thẻ nào
  final String emptyText; // "Trống"
  final String deepLinkUri;

  const ThreeDaysColumnData({
    required this.date,
    required this.dateIso,
    required this.title,
    required this.isToday,
    required this.visibleCards,
    required this.hiddenCount,
    this.badgeText,
    required this.isEmpty,
    this.emptyText = 'Trống',
    required this.deepLinkUri,
  });
}

/// Dữ liệu toàn bộ Widget 3 ngày 4x2
class ThreeDays4x2Data {
  final bool hasSnapshot;
  final String? authMessage; // "Đăng nhập để xem lịch" khi chưa có snapshot
  final List<ThreeDaysColumnData> columns; // Luôn có đúng 3 cột: Hôm nay, Ngày mai, Ngày kia
  final String deepLinkUri;

  const ThreeDays4x2Data({
    required this.hasSnapshot,
    this.authMessage,
    required this.columns,
    this.deepLinkUri = 'tramkien://schedule',
  });
}

/// Bộ chọn dữ liệu thuần cho Widget 3 ngày 4x2
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1, 3.3, 3.5, 3.6, 7
class WidgetThreeDaysSelector {
  static const List<String> kWeekdayNames = [
    '', // 0 (không dùng)
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  /// Rút gọn chuỗi phòng học (ví dụ: "P.102" -> "P102", "B205 (SBD 0123)" -> "B205")
  static String simplifyRoom(String rawRoom) {
    var room = rawRoom.trim();
    if (room.isEmpty) return '';

    // Bỏ phần chú thích trong ngoặc đơn, ví dụ "(SBD 0123)"
    room = room.replaceAll(RegExp(r'\(.*?\)'), '').trim();

    // Chuẩn hóa "P.102", "p.102", "P.H302" -> "P102", "PH302"
    room = room.replaceAllMapped(RegExp(r'^[Pp]\.([A-Za-z0-9]+)'), (m) => 'P${m[1]}');

    return room.trim();
  }

  /// Tính toán dữ liệu 3 cột cho Widget 3 ngày (Hôm nay, Ngày mai, Ngày kia)
  static ThreeDays4x2Data select({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
  }) {
    if (snapshot == null || !snapshot.isValid) {
      final nowVn = WidgetTimeUtils.toVnDateTime(now);
      final emptyColumns = List.generate(3, (i) {
        final colDate = DateTime.utc(nowVn.year, nowVn.month, nowVn.day).add(Duration(days: i));
        final colIso = WidgetTimeUtils.formatVnDateIso(colDate);
        final isToday = i == 0;
        final dayStr = colDate.day.toString().padLeft(2, '0');
        final title = isToday
            ? 'Hôm nay $dayStr'
            : '${kWeekdayNames[colDate.weekday]} · $dayStr';

        return ThreeDaysColumnData(
          date: colDate,
          dateIso: colIso,
          title: title,
          isToday: isToday,
          visibleCards: const [],
          hiddenCount: 0,
          badgeText: null,
          isEmpty: true,
          emptyText: 'Trống',
          deepLinkUri: 'tramkien://schedule?date=$colIso',
        );
      });

      return ThreeDays4x2Data(
        hasSnapshot: false,
        authMessage: 'Đăng nhập để xem lịch',
        columns: emptyColumns,
      );
    }

    final columns = List.generate(3, (i) {
      return selectColumn(
        snapshot: snapshot,
        now: now,
        dayOffset: i,
      );
    });

    return ThreeDays4x2Data(
      hasSnapshot: true,
      authMessage: null,
      columns: columns,
    );
  }

  /// Tính toán dữ liệu cho 1 cột ngày cụ thể (dayOffset: 0 = Hôm nay, 1 = Ngày mai, 2 = Ngày kia)
  static ThreeDaysColumnData selectColumn({
    required WidgetScheduleSnapshot snapshot,
    required DateTime now,
    required int dayOffset,
  }) {
    final nowVn = WidgetTimeUtils.toVnDateTime(now);
    final targetDate = DateTime.utc(nowVn.year, nowVn.month, nowVn.day).add(Duration(days: dayOffset));
    final dateIso = WidgetTimeUtils.formatVnDateIso(targetDate);
    final isToday = dayOffset == 0;
    final dayStr = targetDate.day.toString().padLeft(2, '0');

    // Tiêu đề cột: Cột hôm nay ghi "Hôm nay dd", hai ngày còn lại ghi "Thứ · dd"
    final title = isToday
        ? 'Hôm nay $dayStr'
        : '${kWeekdayNames[targetDate.weekday]} · $dayStr';

    // Lọc các ca học/thi diễn ra trong ngày này (giờ VN)
    final daySessions = snapshot.sessions.where((s) {
      final sDateVn = WidgetTimeUtils.toVnDateTime(s.start);
      return sDateVn.year == targetDate.year &&
          sDateVn.month == targetDate.month &&
          sDateVn.day == targetDate.day;
    }).toList();

    // Sắp xếp theo giờ bắt đầu
    daySessions.sort((a, b) => a.startMs.compareTo(b.startMs));

    // Với cột hôm nay: Bỏ qua môn đã kết thúc (past)
    final List<Session> remainingSessions;
    if (isToday) {
      remainingSessions = daySessions
          .where((s) => s.calculateStatus(now) != SessionStatus.past)
          .toList();
    } else {
      remainingSessions = daySessions;
    }

    // Tối đa 2 thẻ môn:
    // QUY TẮC ƯU TIÊN LỊCH THI (AC-11):
    // Lịch thi mang nền đỏ và LUÔN LUÔN ĐƯỢC ƯU TIÊN VÀO VÙNG HIỂN THỊ (chiếm 1 trong 2 thẻ).
    final exams = remainingSessions
        .where((s) => s.kind == SessionKind.examSession)
        .toList();
    final nonExams = remainingSessions
        .where((s) => s.kind != SessionKind.examSession)
        .toList();

    List<Session> chosenSessions;
    if (exams.isNotEmpty) {
      if (exams.length >= 2) {
        chosenSessions = exams.take(2).toList();
      } else {
        chosenSessions = [exams.first, ...nonExams.take(1)];
      }
      chosenSessions.sort((a, b) => a.startMs.compareTo(b.startMs));
    } else {
      chosenSessions = nonExams.take(2).toList();
    }

    // Chuyển đổi sang ThreeDaysCardItem
    final visibleCards = chosenSessions.map((s) {
      final isExam = s.kind == SessionKind.examSession;
      final isCurrent = isToday && s.calculateStatus(now) == SessionStatus.current;
      final timeStr = WidgetTimeUtils.formatTimeHHmm(s.start);
      final roomStr = simplifyRoom(s.room);
      final timeRoomLine = roomStr.isNotEmpty ? '$timeStr · $roomStr' : timeStr;

      // shortName 1 dòng
      final rawShortName = s.shortName.trim().isNotEmpty ? s.shortName.trim() : s.subjectName.trim();
      final shortName = WidgetHashUtils.formatWithEllipsisPreservation(rawShortName, maxLength: 24);

      final sessionDateIso = WidgetTimeUtils.formatVnDateIso(s.start);
      final deepLink = 'tramkien://schedule?date=$sessionDateIso&sessionId=${s.id}';

      return ThreeDaysCardItem(
        session: s,
        timeStr: timeStr,
        roomStr: roomStr,
        timeRoomLine: timeRoomLine,
        shortName: shortName,
        displayTitle: shortName,
        isExam: isExam,
        isCurrent: isCurrent,
        colorIndex: s.colorIndex,
        deepLinkUri: deepLink,
      );
    }).toList();

    // Số môn bị ẩn: N = remainingSessions.length - chosenSessions.length
    final hiddenCount = remainingSessions.length - chosenSessions.length;
    final badgeText = hiddenCount > 0 ? '+$hiddenCount' : null;

    final isEmpty = visibleCards.isEmpty;

    return ThreeDaysColumnData(
      date: targetDate,
      dateIso: dateIso,
      title: title,
      isToday: isToday,
      visibleCards: visibleCards,
      hiddenCount: hiddenCount > 0 ? hiddenCount : 0,
      badgeText: badgeText,
      isEmpty: isEmpty,
      emptyText: 'Trống',
      deepLinkUri: 'tramkien://schedule?date=$dateIso',
    );
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
