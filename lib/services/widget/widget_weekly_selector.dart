import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_time_utils.dart';
import 'widget_hash_utils.dart';

/// Mục môn học trong danh sách chi tiết của Widget Tuần 4x4
/// (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.4)
class WeeklySessionItem {
  final Session session;
  final String timeStr; // "HH:mm" (bắt đầu)
  final String subjectTitle; // Tên môn gốc
  final String displayTitle; // Tên hiển thị (đã có tiền tố "Thi " nếu là thi)
  final String roomStr; // Phòng viết gọn, ví dụ "P102", "B205"
  final bool isExam; // Môn thi (vạch màu đỏ)
  final bool isPast; // Môn đã kết thúc
  final bool isToday; // Môn thuộc ngày hôm nay
  final int colorIndex; // Bảng 8 màu 0..7
  final String deepLinkUri;

  const WeeklySessionItem({
    required this.session,
    required this.timeStr,
    required this.subjectTitle,
    required this.displayTitle,
    required this.roomStr,
    required this.isExam,
    required this.isPast,
    required this.isToday,
    required this.colorIndex,
    required this.deepLinkUri,
  });
}

/// Dữ liệu cho 1 ngày trong dải 7 ngày (T2..CN)
class WeeklyDayStripItem {
  final DateTime date;
  final String dateIso; // "yyyy-MM-dd"
  final String weekdayLabel; // "T2", "T3", "T4", "T5", "T6", "T7", "CN"
  final int sessionCount;
  final String countText; // "3", "1", "·"
  final bool isToday;
  final bool isPastDay;

  const WeeklyDayStripItem({
    required this.date,
    required this.dateIso,
    required this.weekdayLabel,
    required this.sessionCount,
    required this.countText,
    required this.isToday,
    required this.isPastDay,
  });
}

/// Nhóm ngày có lịch học/thi
class WeeklyDayGroup {
  final DateTime date;
  final String dateIso; // "yyyy-MM-dd"
  final String headerTitle; // "Hôm nay · T4 28/10" hoặc "T5 29/10"
  final bool isToday;
  final List<WeeklySessionItem> sessions;
  final String deepLinkUri;

  const WeeklyDayGroup({
    required this.date,
    required this.dateIso,
    required this.headerTitle,
    required this.isToday,
    required this.sessions,
    required this.deepLinkUri,
  });
}

/// Các ngày trống liên tiếp gộp thành 1 dòng (Ví dụ: "T7 – CN: không có lịch")
class WeeklyMergedEmptyDays {
  final int startIndex; // 0..6
  final int endIndex; // 0..6
  final String startWeekday; // "T7"
  final String endWeekday; // "CN"
  final String displayTitle; // "T7 – CN: không có lịch" hoặc "T3: không có lịch"
  final String deepLinkUri;

  const WeeklyMergedEmptyDays({
    required this.startIndex,
    required this.endIndex,
    required this.startWeekday,
    required this.endWeekday,
    required this.displayTitle,
    required this.deepLinkUri,
  });
}

/// Kiểu mục cho danh sách tuần tổng hợp (hiển thị tuần tự theo thứ tự thời gian)
enum WeeklyItemType {
  dayHeader,
  session,
  mergedEmptyDays,
}

class WeeklyScheduleItem {
  final WeeklyItemType type;
  final WeeklyDayGroup? dayGroup;
  final WeeklySessionItem? sessionItem;
  final WeeklyMergedEmptyDays? emptyDaysItem;

  const WeeklyScheduleItem._({
    required this.type,
    this.dayGroup,
    this.sessionItem,
    this.emptyDaysItem,
  });

  factory WeeklyScheduleItem.dayHeader(WeeklyDayGroup group) => WeeklyScheduleItem._(
        type: WeeklyItemType.dayHeader,
        dayGroup: group,
      );

  factory WeeklyScheduleItem.session(WeeklySessionItem session) => WeeklyScheduleItem._(
        type: WeeklyItemType.session,
        sessionItem: session,
      );

  factory WeeklyScheduleItem.emptyDays(WeeklyMergedEmptyDays emptyDays) => WeeklyScheduleItem._(
        type: WeeklyItemType.mergedEmptyDays,
        emptyDaysItem: emptyDays,
      );
}

/// Dữ liệu toàn bộ Widget Tuần 4x4
class Weekly4x4Data {
  final bool hasSnapshot;
  final String? authMessage; // "Đăng nhập để xem lịch" khi chưa có snapshot
  final int weekOffset;
  final String title; // "Tuần dd/MM – dd/MM"
  final DateTime mondayDate;
  final DateTime sundayDate;
  final List<WeeklyDayStripItem> daysStrip; // Đúng 7 ngày (T2..CN)
  final List<WeeklyDayGroup> dayGroups; // Chỉ các ngày có lịch
  final List<WeeklyMergedEmptyDays> emptyDaysList; // Các khối ngày trống
  final List<WeeklyScheduleItem> items; // Danh sách phẳng xen kẽ hiển thị
  final int totalSessionCount;
  final int hiddenCount; // > 0 khi bị tràn chỗ (iOS)
  final String? footerText; // "+N môn nữa"
  final String deepLinkUri;

  const Weekly4x4Data({
    required this.hasSnapshot,
    this.authMessage,
    required this.weekOffset,
    required this.title,
    required this.mondayDate,
    required this.sundayDate,
    required this.daysStrip,
    required this.dayGroups,
    required this.emptyDaysList,
    required this.items,
    required this.totalSessionCount,
    this.hiddenCount = 0,
    this.footerText,
    this.deepLinkUri = 'tramkien://schedule',
  });
}

/// Bộ chọn dữ liệu thuần cho Widget Tuần (4x4)
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1, 3.4, 3.5, 3.6, 7
class WidgetWeeklySelector {
  static const List<String> kWeekdayLabels = [
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

    // Bỏ chú thích ngoặc đơn
    room = room.replaceAll(RegExp(r'\(.*?\)'), '').trim();

    // Chuẩn hóa "P.102", "p.102" -> "P102"
    room = room.replaceAllMapped(RegExp(r'^[Pp]\.([A-Za-z0-9]+)'), (m) => 'P${m[1]}');

    return room.trim();
  }

  /// Tính toán dữ liệu tuần hoàn chỉnh
  static Weekly4x4Data select({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
    int weekOffset = 0,
  }) {
    final nowVn = WidgetTimeUtils.toVnDateTime(now);
    final todayMidnight = DateTime.utc(nowVn.year, nowVn.month, nowVn.day);

    // Thứ Hai của tuần hiện tại (weekday: 1 là Thứ Hai, 7 là Chủ Nhật)
    final currentMonday = todayMidnight.subtract(Duration(days: nowVn.weekday - 1));

    // Thứ Hai và Chủ Nhật của tuần mục tiêu
    final targetMonday = currentMonday.add(Duration(days: weekOffset * 7));
    final targetSunday = targetMonday.add(const Duration(days: 6));

    final startDayStr = targetMonday.day.toString().padLeft(2, '0');
    final startMonthStr = targetMonday.month.toString().padLeft(2, '0');
    final endDayStr = targetSunday.day.toString().padLeft(2, '0');
    final endMonthStr = targetSunday.month.toString().padLeft(2, '0');

    // "Tuần dd/MM – dd/MM" (en-dash \u2013)
    final weekTitle = 'Tuần $startDayStr/$startMonthStr \u2013 $endDayStr/$endMonthStr';

    // Trường hợp chưa có snapshot hoặc không hợp lệ (AC-10)
    if (snapshot == null || !snapshot.isValid) {
      final emptyStrip = List.generate(7, (i) {
        final d = targetMonday.add(Duration(days: i));
        final isToday = d.year == todayMidnight.year &&
            d.month == todayMidnight.month &&
            d.day == todayMidnight.day;
        final isPastDay = d.isBefore(todayMidnight);
        final dateIso = WidgetTimeUtils.formatVnDateIso(d);

        return WeeklyDayStripItem(
          date: d,
          dateIso: dateIso,
          weekdayLabel: kWeekdayLabels[i],
          sessionCount: 0,
          countText: '\u00B7', // Dấu ·
          isToday: isToday,
          isPastDay: isPastDay,
        );
      });

      return Weekly4x4Data(
        hasSnapshot: false,
        authMessage: 'Đăng nhập để xem lịch',
        weekOffset: weekOffset,
        title: weekTitle,
        mondayDate: targetMonday,
        sundayDate: targetSunday,
        daysStrip: emptyStrip,
        dayGroups: const [],
        emptyDaysList: const [],
        items: const [],
        totalSessionCount: 0,
      );
    }

    // 1. Phân nhóm các phiên theo 7 ngày
    final daySessionsMap = <int, List<Session>>{};
    for (int i = 0; i < 7; i++) {
      daySessionsMap[i] = [];
    }

    for (final s in snapshot.sessions) {
      final sDateVn = WidgetTimeUtils.toVnDateTime(s.start);
      final sDateOnly = DateTime.utc(sDateVn.year, sDateVn.month, sDateVn.day);

      final diffDays = sDateOnly.difference(targetMonday).inDays;
      if (diffDays >= 0 && diffDays < 7) {
        daySessionsMap[diffDays]!.add(s);
      }
    }

    // Sắp xếp các phiên trong từng ngày theo startMs
    for (int i = 0; i < 7; i++) {
      daySessionsMap[i]!.sort((a, b) => a.startMs.compareTo(b.startMs));
    }

    // 2. Tạo dải 7 ngày (Strip)
    final daysStrip = List.generate(7, (i) {
      final d = targetMonday.add(Duration(days: i));
      final isToday = d.year == todayMidnight.year &&
          d.month == todayMidnight.month &&
          d.day == todayMidnight.day;
      final isPastDay = d.isBefore(todayMidnight);
      final dateIso = WidgetTimeUtils.formatVnDateIso(d);
      final count = daySessionsMap[i]!.length;
      final countText = count > 0 ? '$count' : '\u00B7';

      return WeeklyDayStripItem(
        date: d,
        dateIso: dateIso,
        weekdayLabel: kWeekdayLabels[i],
        sessionCount: count,
        countText: countText,
        isToday: isToday,
        isPastDay: isPastDay,
      );
    });

    int totalSessions = 0;
    for (int i = 0; i < 7; i++) {
      totalSessions += daySessionsMap[i]!.length;
    }

    // 3. Xây dựng danh sách nhóm ngày và gộp ngày trống liên tiếp
    final dayGroups = <WeeklyDayGroup>[];
    final emptyDaysList = <WeeklyMergedEmptyDays>[];
    final flatItems = <WeeklyScheduleItem>[];

    int emptyStart = -1;

    void flushEmptyDays(int currentIdx) {
      if (emptyStart != -1) {
        final startIdx = emptyStart;
        final endIdx = currentIdx - 1;
        final startWk = kWeekdayLabels[startIdx];
        final endWk = kWeekdayLabels[endIdx];
        final String displayTitle;
        if (startIdx == endIdx) {
          displayTitle = '$startWk: không có lịch';
        } else {
          displayTitle = '$startWk \u2013 $endWk: không có lịch';
        }

        final emptyDate = targetMonday.add(Duration(days: startIdx));
        final emptyIso = WidgetTimeUtils.formatVnDateIso(emptyDate);

        final merged = WeeklyMergedEmptyDays(
          startIndex: startIdx,
          endIndex: endIdx,
          startWeekday: startWk,
          endWeekday: endWk,
          displayTitle: displayTitle,
          deepLinkUri: 'tramkien://schedule?date=$emptyIso',
        );
        emptyDaysList.add(merged);
        flatItems.add(WeeklyScheduleItem.emptyDays(merged));

        emptyStart = -1;
      }
    }

    for (int i = 0; i < 7; i++) {
      final sessions = daySessionsMap[i]!;
      if (sessions.isEmpty) {
        if (emptyStart == -1) {
          emptyStart = i;
        }
      } else {
        // Kết thúc khối ngày trống trước đó nếu có
        flushEmptyDays(i);

        // Ngày có lịch
        final d = targetMonday.add(Duration(days: i));
        final isToday = d.year == todayMidnight.year &&
            d.month == todayMidnight.month &&
            d.day == todayMidnight.day;
        final dateIso = WidgetTimeUtils.formatVnDateIso(d);
        final dayStr = d.day.toString().padLeft(2, '0');
        final monthStr = d.month.toString().padLeft(2, '0');
        final wkStr = kWeekdayLabels[i];

        final String headerTitle;
        if (isToday) {
          headerTitle = 'Hôm nay \u00B7 $wkStr $dayStr/$monthStr';
        } else {
          headerTitle = '$wkStr $dayStr/$monthStr';
        }

        final groupSessions = sessions.map((s) {
          final isExam = s.kind == SessionKind.examSession;
          final isPast = s.calculateStatus(now) == SessionStatus.past;
          final timeStr = WidgetTimeUtils.formatTimeHHmm(s.start);
          final roomStr = simplifyRoom(s.room);

          // Tên môn hiển thị: nếu là thi thì có tiền tố "Thi "
          final rawName = s.subjectName.trim();
          final titleWithPrefix = isExam ? 'Thi $rawName' : rawName;
          final displayTitle = WidgetHashUtils.formatWithEllipsisPreservation(titleWithPrefix, maxLength: 36);

          final sDateIso = WidgetTimeUtils.formatVnDateIso(s.start);
          final deepLink = 'tramkien://schedule?date=$sDateIso&sessionId=${s.id}';

          return WeeklySessionItem(
            session: s,
            timeStr: timeStr,
            subjectTitle: rawName,
            displayTitle: displayTitle,
            roomStr: roomStr,
            isExam: isExam,
            isPast: isPast,
            isToday: isToday,
            colorIndex: s.colorIndex,
            deepLinkUri: deepLink,
          );
        }).toList();

        final group = WeeklyDayGroup(
          date: d,
          dateIso: dateIso,
          headerTitle: headerTitle,
          isToday: isToday,
          sessions: groupSessions,
          deepLinkUri: 'tramkien://schedule?date=$dateIso',
        );

        dayGroups.add(group);
        flatItems.add(WeeklyScheduleItem.dayHeader(group));
        for (final sessionItem in groupSessions) {
          flatItems.add(WeeklyScheduleItem.session(sessionItem));
        }
      }
    }

    // Kết thúc khối ngày trống ở cuối tuần nếu có (ví dụ T7 - CN)
    flushEmptyDays(7);

    return Weekly4x4Data(
      hasSnapshot: true,
      authMessage: null,
      weekOffset: weekOffset,
      title: weekTitle,
      mondayDate: targetMonday,
      sundayDate: targetSunday,
      daysStrip: daysStrip,
      dayGroups: dayGroups,
      emptyDaysList: emptyDaysList,
      items: flatItems,
      totalSessionCount: totalSessions,
      hiddenCount: 0,
      footerText: null,
    );
  }

  /// Tính toán danh sách giới hạn số hàng cho iOS Widget / Bố cục tràn chỗ (AC-11)
  /// ĐẶC BIỆT: Lịch thi chưa diễn ra trong tuần tuyệt đối không bị cắt (AC-11)
  static Weekly4x4Data selectWithLimit({
    required WidgetScheduleSnapshot? snapshot,
    required DateTime now,
    int weekOffset = 0,
    required int maxSessions,
  }) {
    final fullData = select(
      snapshot: snapshot,
      now: now,
      weekOffset: weekOffset,
    );

    if (!fullData.hasSnapshot || fullData.totalSessionCount <= maxSessions) {
      return fullData;
    }

    // Lấy toàn bộ sessions phẳng từ fullData
    final allSessions = <WeeklySessionItem>[];
    for (final group in fullData.dayGroups) {
      allSessions.addAll(group.sessions);
    }

    // AC-11: Tách các ca thi CHƯA DIỄN RA (!isPast)
    final activeExams = allSessions.where((s) => s.isExam && !s.isPast).toList();
    final otherSessions = allSessions.where((s) => !(s.isExam && !s.isPast)).toList();

    // Các ca thi chưa diễn ra luôn được ưu tiên 100%
    final chosenSet = <int>{};
    final chosenSessions = <WeeklySessionItem>[];

    for (final exam in activeExams) {
      chosenSessions.add(exam);
      chosenSet.add(exam.session.id);
    }

    // Còn bao nhiêu chỗ trống thì điền từ otherSessions theo thứ tự thời gian
    final remainingSlots = maxSessions > chosenSessions.length ? maxSessions - chosenSessions.length : 0;
    for (final s in otherSessions) {
      if (chosenSessions.length >= maxSessions && chosenSet.length >= activeExams.length + remainingSlots) {
        break;
      }
      if (!chosenSet.contains(s.session.id)) {
        chosenSessions.add(s);
        chosenSet.add(s.session.id);
      }
    }

    // Sắp xếp lại danh sách được chọn theo thời gian
    chosenSessions.sort((a, b) => a.session.startMs.compareTo(b.session.startMs));

    final hiddenCount = fullData.totalSessionCount - chosenSessions.length;
    final footerText = hiddenCount > 0 ? '+$hiddenCount môn nữa' : null;

    // Tái cấu trúc dayGroups và flat items với các sessions được chọn
    final chosenByDateIso = <String, List<WeeklySessionItem>>{};
    for (final s in chosenSessions) {
      final sDateIso = WidgetTimeUtils.formatVnDateIso(s.session.start);
      chosenByDateIso.putIfAbsent(sDateIso, () => []).add(s);
    }

    final limitedGroups = <WeeklyDayGroup>[];
    final limitedItems = <WeeklyScheduleItem>[];

    // Duyệt qua items gốc: giữ header nếu có session con được hiển thị, giữ empty days
    for (final group in fullData.dayGroups) {
      final groupChosen = chosenByDateIso[group.dateIso] ?? [];
      if (groupChosen.isNotEmpty) {
        final newGroup = WeeklyDayGroup(
          date: group.date,
          dateIso: group.dateIso,
          headerTitle: group.headerTitle,
          isToday: group.isToday,
          sessions: groupChosen,
          deepLinkUri: group.deepLinkUri,
        );
        limitedGroups.add(newGroup);
        limitedItems.add(WeeklyScheduleItem.dayHeader(newGroup));
        for (final s in groupChosen) {
          limitedItems.add(WeeklyScheduleItem.session(s));
        }
      }
    }

    // Thêm các empty days
    for (final empty in fullData.emptyDaysList) {
      limitedItems.add(WeeklyScheduleItem.emptyDays(empty));
    }

    return Weekly4x4Data(
      hasSnapshot: fullData.hasSnapshot,
      authMessage: fullData.authMessage,
      weekOffset: fullData.weekOffset,
      title: fullData.title,
      mondayDate: fullData.mondayDate,
      sundayDate: fullData.sundayDate,
      daysStrip: fullData.daysStrip,
      dayGroups: limitedGroups,
      emptyDaysList: fullData.emptyDaysList,
      items: limitedItems,
      totalSessionCount: fullData.totalSessionCount,
      hiddenCount: hiddenCount,
      footerText: footerText,
    );
  }
}
