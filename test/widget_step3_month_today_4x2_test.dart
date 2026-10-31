import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/widgets/widget_month_today_4x2_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mốc chuẩn Spec: 28/10/2026 (Thứ Tư)
  final testYear = 2026;
  final testMonth = 10;
  final testDay = 28;

  // Phiên 1: 26/10/2026 (Thứ Hai) - 3 môn
  final sessionT2_1 = Session(
    id: 1,
    kind: SessionKind.classSession,
    subjectName: 'Môn Thứ Hai 1',
    shortName: 'T2-1',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 9, 20),
    room: 'P.101',
    colorIndex: 0,
  );

  // Phiên 2: 27/10/2026 (Thứ Ba) - 1 môn
  final sessionT3 = Session(
    id: 2,
    kind: SessionKind.classSession,
    subjectName: 'Môn Thứ Ba',
    shortName: 'T3',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 27, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 27, 9, 20),
    room: 'P.102',
    colorIndex: 1,
  );

  // Phiên 3: 14/10/2026 (Thứ Tư) - 1 ca thi (chấm đỏ lưới tháng)
  final sessionExam14 = Session(
    id: 14,
    kind: SessionKind.examSession,
    subjectName: 'Thi Tiếng Anh chuyên ngành',
    shortName: 'TA CN',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 14, 14, 0),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 14, 15, 30),
    room: 'B101',
    colorIndex: 4,
    endEstimated: true,
  );

  // Ngày hôm nay: 28/10/2026 - 4 môn theo Bảng 5.1 Spec
  // 1. Lập trình Web (06:55 - 09:20 VN)
  final sessionWeb = Session(
    id: 101,
    kind: SessionKind.classSession,
    subjectName: 'Lập trình Web',
    shortName: 'LT Web',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 20),
    room: 'P.301',
    teacher: 'Th. Hòa',
    colorIndex: 2,
    endEstimated: false,
  );

  // 2. Thi PPL NCKH (09:45 - 11:45 VN, 120 phút, kind == exam)
  final sessionExamPpl = Session(
    id: 102,
    kind: SessionKind.examSession,
    subjectName: 'Phương pháp luận nghiên cứu khoa học',
    shortName: 'PPL NCKH',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 45),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 11, 45),
    room: 'B205',
    colorIndex: 5,
    endEstimated: false,
  );

  // 3. Cấu trúc dữ liệu và giải thuật 2 (12:55 - 15:25 VN)
  final sessionCtdl2 = Session(
    id: 103,
    kind: SessionKind.classSession,
    subjectName: 'Cấu trúc dữ liệu và giải thuật 2',
    shortName: 'CTDL & GT 2',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 15, 25),
    room: 'P.102',
    teacher: 'Cô Mai',
    colorIndex: 0,
    endEstimated: false,
  );

  // 4. Mạng máy tính (15:30 - 17:05 VN)
  final sessionNetwork = Session(
    id: 104,
    kind: SessionKind.classSession,
    subjectName: 'Mạng máy tính',
    shortName: 'Mạng máy tính',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 15, 30),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 17, 5),
    room: 'P.204',
    colorIndex: 3,
    endEstimated: false,
  );

  // 29/10/2026: Mạng máy tính (06:55 - 09:20 VN)
  final sessionT5 = Session(
    id: 201,
    kind: SessionKind.classSession,
    subjectName: 'Mạng máy tính',
    shortName: 'Mạng máy tính',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 9, 20),
    room: 'P.204',
    colorIndex: 3,
  );

  // 30/10/2026: Đồ án CN (12:55 - 15:25 VN)
  final sessionT6 = Session(
    id: 202,
    kind: SessionKind.classSession,
    subjectName: 'Đồ án CN',
    shortName: 'Đồ án CN',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 2, 12, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 2, 15, 25),
    room: 'Lab3',
    colorIndex: 6,
  );

  final fullSnapshot = WidgetScheduleSnapshot(
    version: 1,
    generatedAt: DateTime.now().millisecondsSinceEpoch,
    sessions: [
      sessionExam14,
      sessionT2_1,
      sessionT3,
      sessionWeb,
      sessionExamPpl,
      sessionCtdl2,
      sessionNetwork,
      sessionT5,
      sessionT6,
    ],
  );

  group('1. Lưới tháng & Điều hướng (SPEC Mục 3.2)', () {
    test('Tiêu đề tháng, hàng thứ và cấu trúc lưới 7 cột', () {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final grid = WidgetMonthTodaySelector.selectMonthGrid(snapshot: fullSnapshot, now: now1005);

      expect(grid.monthTitle, 'Tháng 10/2026');
      expect(grid.weekdayHeaders, ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
      expect(grid.rows.length, 5); // Tháng 10/2026 bắt đầu từ Thứ Năm -> 5 hàng (35 ô)
      expect(grid.cells.length, 35);

      // Ngày 01/10/2026 là Thứ Năm (T5) -> 3 ô trống đầu tiên (T2, T3, T4)
      expect(grid.cells[0], isNull);
      expect(grid.cells[1], isNull);
      expect(grid.cells[2], isNull);
      expect(grid.cells[3]!.day, 1);
      expect(grid.cells[3]!.month, 10);
      expect(grid.cells[3]!.year, 2026);

      // Ngày 31/10/2026 là Thứ Bảy (T7) -> ngày cuối tại index 33, ô 34 (CN) là null
      expect(grid.cells[33]!.day, 31);
      expect(grid.cells[34], isNull);
    });

    test('Chuyển tháng qua monthOffset (Nút ‹ ›)', () {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

      // Tháng sau (monthOffset = 1) -> Tháng 11/2026 (30 ngày)
      final gridNext = WidgetMonthTodaySelector.selectMonthGrid(snapshot: fullSnapshot, now: now1005, monthOffset: 1);
      expect(gridNext.monthTitle, 'Tháng 11/2026');
      expect(gridNext.year, 2026);
      expect(gridNext.month, 11);

      // Tháng trước (monthOffset = -1) -> Tháng 9/2026 (30 ngày)
      final gridPrev = WidgetMonthTodaySelector.selectMonthGrid(snapshot: fullSnapshot, now: now1005, monthOffset: -1);
      expect(gridPrev.monthTitle, 'Tháng 9/2026');
      expect(gridPrev.year, 2026);
      expect(gridPrev.month, 9);

      // Đổi năm qua tháng 1/2027 (monthOffset = 3)
      final gridNextYear = WidgetMonthTodaySelector.selectMonthGrid(snapshot: fullSnapshot, now: now1005, monthOffset: 3);
      expect(gridNextYear.monthTitle, 'Tháng 1/2027');
      expect(gridNextYear.year, 2027);
      expect(gridNextYear.month, 1);
    });
  });

  group('2. Điểm đánh dấu trên lưới tháng (SPEC Mục 3.2 & 5.2)', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
    final grid = WidgetMonthTodaySelector.selectMonthGrid(snapshot: fullSnapshot, now: now1005);

    test('Ngày có thi (14/10): Chấm đỏ thi 3pt dưới số', () {
      final day14 = grid.cells.firstWhere((c) => c?.day == 14)!;
      expect(day14.hasExam, isTrue);
      expect(day14.showExamDot, isTrue);
      expect(day14.isToday, isFalse);
      expect(day14.deepLinkUri, 'tramkien://schedule?date=2026-10-14');
    });

    test('Ngày có học thường (26/10, 27/10, 29/10, 30/10): Chấm màu phụ dưới số', () {
      final day26 = grid.cells.firstWhere((c) => c?.day == 26)!;
      expect(day26.hasClasses, isTrue);
      expect(day26.hasExam, isFalse);
      expect(day26.showStudyDot, isTrue);
      expect(day26.showExamDot, isFalse);
      expect(day26.isToday, isFalse);

      final day27 = grid.cells.firstWhere((c) => c?.day == 27)!;
      expect(day27.showStudyDot, isTrue);

      final day29 = grid.cells.firstWhere((c) => c?.day == 29)!;
      expect(day29.showStudyDot, isTrue);

      final day30 = grid.cells.firstWhere((c) => c?.day == 30)!;
      expect(day30.showStudyDot, isTrue);
    });

    test('Hôm nay có thi (28/10): Vòng tròn accent quanh số + Chấm đỏ thi phía DƯỚI', () {
      final day28 = grid.cells.firstWhere((c) => c?.day == 28)!;
      expect(day28.isToday, isTrue);
      expect(day28.hasExam, isTrue); // có ca thi PPL NCKH
      expect(day28.showExamDot, isTrue); // chấm đỏ phía dưới vòng tròn accent
      expect(day28.showStudyDot, isFalse); // không dùng chấm study khi là hôm nay có thi
      expect(day28.deepLinkUri, 'tramkien://schedule?date=2026-10-28');
    });

    test('Ngày không có lịch (01/10, 31/10): Chữ màu phụ, không có chấm', () {
      final day1 = grid.cells.firstWhere((c) => c?.day == 1)!;
      expect(day1.hasSchedule, isFalse);
      expect(day1.showStudyDot, isFalse);
      expect(day1.showExamDot, isFalse);

      final day31 = grid.cells.firstWhere((c) => c?.day == 31)!;
      expect(day31.hasSchedule, isFalse);
      expect(day31.showStudyDot, isFalse);
      expect(day31.showExamDot, isFalse);
    });
  });

  group('3. Nửa phải: Lịch hôm nay & Mốc kiểm thử 28/10/2026 10:05 (Mục 3.2 & 5.2)', () {
    test('Xác thực mốc Spec 28/10/2026 10:05: Header, 2 Thẻ môn, +1 môn nữa', () {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final todayData = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: fullSnapshot, now: now1005);

      // Header: "T4, 28/10" bên trái, "4 môn" bên phải
      expect(todayData.headerLeft, 'T4, 28/10');
      expect(todayData.headerRight, '4 môn');
      expect(todayData.totalSessionsToday, 4);

      // 4 môn hôm nay:
      // 1. 06:55-09:20 Lập trình Web -> past (không hiển thị trong thẻ)
      // 2. 09:45-11:45 Thi PPL NCKH -> current (Exam) -> Thẻ 1
      // 3. 12:55-15:25 CTDL & GT 2 -> upcoming -> Thẻ 2
      // 4. 15:30-17:05 Mạng máy tính -> upcoming -> Overflow
      expect(todayData.visibleCards.length, 2);

      // Thẻ 1: Môn thi PPL NCKH
      final card1 = todayData.visibleCards[0];
      expect(card1.isExam, isTrue);
      expect(card1.isCurrent, isTrue); // 10:05 nằm trong 09:45 - 11:45
      expect(card1.timeRoomLine, '09:45 · B205 · Thi');
      expect(card1.session.subjectName, 'Phương pháp luận nghiên cứu khoa học');
      expect(card1.deepLinkUri, contains('sessionId=102'));

      // Thẻ 2: Cấu trúc dữ liệu và giải thuật 2
      final card2 = todayData.visibleCards[1];
      expect(card2.isExam, isFalse);
      expect(card2.isCurrent, isFalse);
      expect(card2.timeRoomLine, '12:55 · P.102');
      expect(card2.displayTitle, contains('2')); // bảo tồn hậu tố số 2 (AC-09)
      expect(card2.deepLinkUri, contains('sessionId=103'));

      // Footer: +1 môn nữa
      expect(todayData.overflowCount, 1);
      expect(todayData.overflowLabel, '+1 môn nữa');
    });

    test('AC-11: Quy tắc ưu tiên lịch thi chưa diễn ra dù ở mốc giờ xa hơn trong ngày', () {
      // Giả sử có 2 ca học buổi sáng và 1 ca thi buổi chiều:
      // Ca 1: Học 06:55 - 09:20
      // Ca 2: Học 09:45 - 11:45
      // Ca 3: Thi 15:30 - 17:00
      final morningClass1 = Session(
        id: 501,
        kind: SessionKind.classSession,
        subjectName: 'Môn sáng 1',
        shortName: 'MS1',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 6, 55),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 20),
        room: 'P.101',
        colorIndex: 0,
      );
      final morningClass2 = Session(
        id: 502,
        kind: SessionKind.classSession,
        subjectName: 'Môn sáng 2',
        shortName: 'MS2',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 45),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 11, 45),
        room: 'P.102',
        colorIndex: 1,
      );
      final afternoonExam = Session(
        id: 503,
        kind: SessionKind.examSession,
        subjectName: 'Thi cuối kỳ buổi chiều',
        shortName: 'Thi CK',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 15, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 17, 0),
        room: 'B201',
        colorIndex: 2,
      );

      final snapshotPriority = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [morningClass1, morningClass2, afternoonExam],
      );

      // Tại mốc 06:00 (cả 3 ca đều upcoming):
      final now0600 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 6, 0);
      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: snapshotPriority, now: now0600);

      expect(data.visibleCards.length, 2);
      // Thẻ 1: Môn sáng 1 (06:55)
      expect(data.visibleCards[0].session.id, 501);
      // Thẻ 2: BẮT BUỘC LÀ CA THI (15:30) vì ca thi được ưu tiên vị trí hiển thị (AC-11),
      // mặc dù Môn sáng 2 (09:45) diễn ra sớm hơn!
      expect(data.visibleCards[1].isExam, isTrue);
      expect(data.visibleCards[1].session.id, 503);
      expect(data.visibleCards[1].timeRoomLine, '15:30 · B201 · Thi');

      // Môn sáng 2 bị đẩy vào số đếm overflow (+1 môn nữa)
      expect(data.overflowCount, 1);
      expect(data.overflowLabel, '+1 môn nữa');
    });

    test('Kỷ luật đếm tràn overflow: Chỉ hiện +N khi N > 0, không bao giờ hiện +0', () {
      // Khi chỉ còn 2 môn chưa qua -> vừa khít 2 thẻ -> overflow = 0, label = null
      final now1200 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 0);
      // Lúc 12:00: Web và Thi PPL NCKH đã qua -> chỉ còn CTDL2 (12:55) và Mạng máy tính (15:30)
      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: fullSnapshot, now: now1200);

      expect(data.visibleCards.length, 2);
      expect(data.overflowCount, 0);
      expect(data.overflowLabel, isNull); // KHÔNG HIỆN +0
    });
  });

  group('4. Bốn trạng thái trống chuẩn (Mục 3.6 & AC-10)', () {
    test('Trạng thái 0: Chưa có bản chụp / chưa đăng nhập -> "Đăng nhập để xem lịch"', () {
      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: null, now: now);

      expect(data.stateType, Today2x2StateType.noSnapshot);
      expect(data.emptyTitle, 'Đăng nhập để xem lịch');
      expect(data.visibleCards, isEmpty);
      expect(data.headerRight, '0 môn');
    });

    test('Trạng thái 1: Hôm nay không có lịch kèm ca tiếp theo trong 7 ngày', () {
      // Kiểm thử ngày 31/10/2026 (Thứ Bảy - ngày nghỉ theo Spec)
      final nowT7 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 31, 8, 0);
      // Tạo snapshot chỉ có ca học ngày Thứ Hai tuần tới (02/11/2026)
      final nextMondaySession = Session(
        id: 999,
        kind: SessionKind.classSession,
        subjectName: 'Mạng máy tính nâng cao',
        shortName: 'MMT NC',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, 11, 2, 6, 55),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, 11, 2, 9, 20),
        room: 'P.201',
        colorIndex: 3,
      );
      final snapEmptyDay = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [nextMondaySession],
      );

      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: snapEmptyDay, now: nowT7);

      expect(data.stateType, Today2x2StateType.emptyDay);
      expect(data.emptyTitle, 'Hôm nay không có lịch');
      expect(data.emptySubtitle, contains('Tiếp theo: T2 06:55 MMT NC'));
      expect(data.visibleCards, isEmpty);
    });

    test('Trạng thái 1: Hôm nay không có lịch và 7 ngày tới hoàn toàn trống', () {
      final nowT7 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 31, 8, 0);
      final snapEmpty = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: const [],
      );

      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: snapEmpty, now: nowT7);

      expect(data.stateType, Today2x2StateType.emptyDay);
      expect(data.emptyTitle, 'Hôm nay không có lịch');
      expect(data.emptySubtitle, 'Không có lịch sắp tới');
    });

    test('Trạng thái 2: Đã kết thúc toàn bộ ca học trong ngày', () {
      // 28/10/2026 lúc 18:00 VN (cả 4 môn đều đã xong)
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final data = WidgetMonthTodaySelector.selectTodaySchedule(snapshot: fullSnapshot, now: now1800);

      expect(data.stateType, Today2x2StateType.allFinished);
      expect(data.emptyTitle, 'Hôm nay đã xong 4 môn');
      expect(data.emptySubtitle, contains('Tiếp theo: T5 06:55 Mạng máy tính'));
      expect(data.visibleCards, isEmpty);
    });
  });

  group('5. Quy tắc cắt tên dài bảo tồn hậu tố (AC-09)', () {
    test('Bảo tồn hậu tố số 2 khi cắt giữa tên môn dài', () {
      final longTitle = 'Cấu trúc dữ liệu và giải thuật nâng cao chuyên ngành 2';
      final formatted = WidgetMonthTodaySelector.formatWithEllipsisPreservation(longTitle, maxLength: 36);

      expect(formatted.endsWith('2'), isTrue);
      expect(formatted.contains('…'), isTrue);
      expect(formatted.length, lessThanOrEqualTo(36));
    });

    test('Bảo tồn hậu tố chữ số La Mã khi cắt giữa', () {
      final longTitle = 'Phương pháp tính toán và giải tích toán học III';
      final formatted = WidgetMonthTodaySelector.formatWithEllipsisPreservation(longTitle, maxLength: 36);

      expect(formatted.endsWith('III'), isTrue);
      expect(formatted.contains('…'), isTrue);
      expect(formatted.length, lessThanOrEqualTo(36));
    });

    test('Tên ngắn giữ nguyên không bị chèn dấu ba chấm', () {
      final shortTitle = 'Mạng máy tính';
      final formatted = WidgetMonthTodaySelector.formatWithEllipsisPreservation(shortTitle, maxLength: 36);

      expect(formatted, shortTitle);
      expect(formatted.contains('…'), isFalse);
    });
  });

  group('6. Tính mốc đổi trạng thái tiếp theo cho AlarmManager & Timeline (Mục 4.3)', () {
    test('getNextTransitionTime tính chính xác mốc chuyển trạng thái tiếp theo', () {
      // Tại mốc 10:05, ca thi kết thúc lúc 11:45 VN -> mốc đổi tiếp theo là 11:45
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final nextTime = WidgetMonthTodaySelector.getNextTransitionTime(snapshot: fullSnapshot, now: now1005);

      expect(nextTime.isUtc, isTrue);
      final vnNext = WidgetTimeUtils.toVnDateTime(nextTime);
      expect(vnNext.hour, 11);
      expect(vnNext.minute, 45);
    });

    test('getAllDayTransitionTimes sinh đầy đủ mốc bắt đầu, kết thúc và nửa đêm', () {
      final now0700 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 7, 0);
      final transitions = WidgetMonthTodaySelector.getAllDayTransitionTimes(snapshot: fullSnapshot, now: now0700);

      expect(transitions.isNotEmpty, isTrue);
      // Phải có mốc nửa đêm hôm sau 00:00
      final hasMidnight = transitions.any((t) {
        final vn = WidgetTimeUtils.toVnDateTime(t);
        return vn.day == testDay + 1 && vn.hour == 0 && vn.minute == 0;
      });
      expect(hasMidnight, isTrue);
    });
  });

  group('7. Kiểm định AC-08: Zero Hardcoded Time Strings trong mã nguồn Bước 3', () {
    test('Không có mốc giờ cố định \\b\\d{1,2}:\\d{2}\\b trong mã nguồn widget', () {
      final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

      final filesToCheck = [
        'android/app/src/main/kotlin/com/tramkien/hau/MonthToday4x2ScheduleWidgetProvider.kt',
        'android/app/src/main/res/layout/widget_schedule_month_today_4x2.xml',
        'android/app/src/main/res/xml/widget_schedule_month_today_4x2_info.xml',
        'ios/Runner/ScheduleWidgetKit.swift',
        'lib/services/widget/widget_month_today_selector.dart',
        'lib/widgets/widget_month_today_4x2_card.dart',
      ];

      for (final relPath in filesToCheck) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'File $relPath phải tồn tại');

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();

          // Bỏ qua các dòng chú thích code
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('<!--')) {
            continue;
          }

          // Lọc bỏ chú thích inline
          var codePart = line.replaceAll(RegExp(r'//.*$'), '');
          codePart = codePart.replaceAll(RegExp(r'<!--.*?-->'), '');

          final matches = timeRegex.allMatches(codePart);
          expect(
            matches.isEmpty,
            isTrue,
            reason: 'Phát hiện mốc giờ hardcode ${matches.map((m) => m.group(0)).toList()} tại $relPath:${i + 1}',
          );
        }
      }
    });
  });

  group('8. Widget Test: Render Widget Tháng + Hôm nay 4x2 (Flutter Parity Card)', () {
    testWidgets('Render chuẩn mốc Spec 28/10/2026 10:05: Nửa trái và Nửa phải', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetMonthTodaySelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetMonthToday4x2Card(data: data),
            ),
          ),
        ),
      );

      // Nửa trái
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(find.text('T2'), findsWidgets);
      expect(find.text('28'), findsOneWidget); // Hôm nay
      expect(find.text('14'), findsOneWidget); // Ngày thi

      // Nửa phải
      expect(find.text('T4, 28/10'), findsOneWidget);
      expect(find.text('4 môn'), findsOneWidget);
      expect(find.text('09:45 · B205 · Thi'), findsOneWidget);
      expect(find.text('12:55 · P.102'), findsOneWidget);
      expect(find.text('+1 môn nữa'), findsOneWidget);
    });

    testWidgets('Render Dark mode chính xác theo Token Mục 1.4 & 1.5', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetMonthTodaySelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: WidgetMonthToday4x2Card(data: data, isDarkMode: true),
            ),
          ),
        ),
      );

      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(find.text('09:45 · B205 · Thi'), findsOneWidget);
    });

    testWidgets('Render trạng thái trống "Đăng nhập để xem lịch"', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetMonthTodaySelector.select(snapshot: null, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetMonthToday4x2Card(data: data),
            ),
          ),
        ),
      );

      expect(find.text('Đăng nhập để xem lịch'), findsOneWidget);
    });

    testWidgets('Render trạng thái trống "Hôm nay không có lịch"', (tester) async {
      final nowT7 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 31, 8, 0);
      final snapEmpty = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: const [],
      );
      final data = WidgetMonthTodaySelector.select(snapshot: snapEmpty, now: nowT7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetMonthToday4x2Card(data: data),
            ),
          ),
        ),
      );

      expect(find.text('Hôm nay không có lịch'), findsOneWidget);
      expect(find.text('Không có lịch sắp tới'), findsOneWidget);
    });

    testWidgets('Render trạng thái "Hôm nay đã xong 4 môn"', (tester) async {
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final data = WidgetMonthTodaySelector.select(snapshot: fullSnapshot, now: now1800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetMonthToday4x2Card(data: data),
            ),
          ),
        ),
      );

      expect(find.text('Hôm nay đã xong 4 môn'), findsOneWidget);
      expect(find.textContaining('Tiếp theo: T5 06:55 Mạng máy tính'), findsOneWidget);
    });
  });
}
