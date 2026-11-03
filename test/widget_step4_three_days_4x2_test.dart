import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/widgets/widget_three_days_4x2_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mốc chuẩn Spec: 28/10/2026 (Thứ Tư)
  const testYear = 2026;
  const testMonth = 10;
  const testDay = 28;

  // ==================== CÁC PHIÊN THEO BẢNG 5.1 SPEC ====================
  // Ngày 28/10/2026 (Thứ Tư - Hôm nay): 4 môn
  // 1. Lập trình Web (06:55 - 09:20 VN, past tại 10:05)
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

  // 2. Thi PPL NCKH (09:45 - 11:45 VN, 120 phút, kind == exam, current tại 10:05)
  final sessionExamPpl = Session(
    id: 102,
    kind: SessionKind.examSession,
    subjectName: 'Phương pháp luận nghiên cứu khoa học',
    shortName: 'PPL NCKH',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 45),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 11, 45),
    room: 'B205 (SBD 0123)',
    colorIndex: 5,
    endEstimated: false,
  );

  // 3. Cấu trúc dữ liệu và giải thuật 2 (12:55 - 15:25 VN, upcoming)
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

  // 4. Mạng máy tính (15:30 - 17:05 VN, upcoming)
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

  // Ngày 29/10/2026 (Thứ Năm - Ngày mai): 2 môn theo Bảng 5.1
  // 1. Mạng máy tính (06:55 - 09:20 VN)
  final sessionT5_1 = Session(
    id: 201,
    kind: SessionKind.classSession,
    subjectName: 'Mạng máy tính',
    shortName: 'Mạng máy tính',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 9, 20),
    room: 'P.204',
    colorIndex: 3,
  );

  // 2. Thể dục (12:55 - 15:25 VN)
  final sessionT5_2 = Session(
    id: 202,
    kind: SessionKind.classSession,
    subjectName: 'Thể dục',
    shortName: 'Thể dục',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 12, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 15, 25),
    room: 'Sân A',
    colorIndex: 1,
  );

  // Ngày 30/10/2026 (Thứ Sáu - Ngày kia): 1 môn theo Bảng 5.1
  // 1. Đồ án CN (12:55 - 15:25 VN)
  final sessionT6 = Session(
    id: 301,
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
      sessionWeb,
      sessionExamPpl,
      sessionCtdl2,
      sessionNetwork,
      sessionT5_1,
      sessionT5_2,
      sessionT6,
    ],
  );

  final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

  group('1. Cấu trúc 3 cột & Tiêu đề cột (SPEC Mục 3.3)', () {
    test('Cột hôm nay ghi "Hôm nay dd", hai ngày còn lại ghi "Thứ · dd"', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);

      expect(data.columns.length, 3);
      // Cột 1: Hôm nay 28
      expect(data.columns[0].isToday, isTrue);
      expect(data.columns[0].title, 'Hôm nay 28');
      expect(data.columns[0].dateIso, '2026-10-28');

      // Cột 2: T5 · 29
      expect(data.columns[1].isToday, isFalse);
      expect(data.columns[1].title, 'T5 · 29');
      expect(data.columns[1].dateIso, '2026-10-29');

      // Cột 3: T6 · 30
      expect(data.columns[2].isToday, isFalse);
      expect(data.columns[2].title, 'T6 · 30');
      expect(data.columns[2].dateIso, '2026-10-30');
    });

    test('Chuyển ngày qua các thứ khác nhau: T7 · dd, CN · dd, T2 · dd', () {
      // Giả sử hôm nay là Thứ Sáu 30/10/2026
      final nowFriday = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 30, 8, 0);
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: nowFriday);

      expect(data.columns[0].title, 'Hôm nay 30');
      expect(data.columns[1].title, 'T7 · 31');
      expect(data.columns[2].title, 'CN · 01'); // Qua tháng 11
    });
  });

  group('2. Kỷ luật ẩn hiện "+N" & Bỏ "+0" (SPEC Mục 3.3 & 5.2)', () {
    test('Cột hôm nay 28/10: Có 3 môn còn lại, hiện đủ cả 3 thẻ (sức chứa 4 thẻ)', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final colToday = data.columns[0];

      expect(colToday.visibleCards.length, 3);
      expect(colToday.hiddenCount, 0);
      expect(colToday.badgeText, isNull);
    });

    test('Cột T5 (29/10): Có đúng 2 môn, hiện cả 2 thẻ -> ẩn hoàn toàn "+N" (bỏ +0)', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final colT5 = data.columns[1];

      expect(colT5.visibleCards.length, 2);
      expect(colT5.hiddenCount, 0);
      expect(colT5.badgeText, isNull); // TUYỆT ĐỐI KHÔNG HIỂN THỊ +0
    });

    test('Cột T6 (30/10): Có 1 môn, hiện 1 thẻ -> ẩn hoàn toàn "+N"', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final colT6 = data.columns[2];

      expect(colT6.visibleCards.length, 1);
      expect(colT6.hiddenCount, 0);
      expect(colT6.badgeText, isNull);
    });

    test('Ngày có 4 môn chưa qua -> hiển thị đủ cả 4 thẻ (sức chứa 4 thẻ)', () {
      // Giả sử T5 có thêm 2 môn nữa thành 4 môn
      final extra1 = Session(
        id: 203,
        kind: SessionKind.classSession,
        subjectName: 'Môn Thêm 1',
        shortName: 'Thêm 1',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 15, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 17, 5),
        room: 'P.101',
        colorIndex: 4,
      );
      final extra2 = Session(
        id: 204,
        kind: SessionKind.classSession,
        subjectName: 'Môn Thêm 2',
        shortName: 'Thêm 2',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 17, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 19, 0),
        room: 'P.102',
        colorIndex: 5,
      );

      final snapshotWith4 = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [...fullSnapshot.sessions, extra1, extra2],
      );

      final data = WidgetThreeDaysSelector.select(snapshot: snapshotWith4, now: now1005);
      final colT5 = data.columns[1];

      expect(colT5.visibleCards.length, 4);
      expect(colT5.hiddenCount, 0);
      expect(colT5.badgeText, isNull);
    });
  });

  group('3. Tối đa 2 thẻ/cột, shortName 1 dòng & Phòng viết gọn (SPEC Mục 2.3 & 3.3)', () {
    test('Hàm simplifyRoom rút gọn phòng chính xác', () {
      expect(WidgetThreeDaysSelector.simplifyRoom('P.301'), 'P301');
      expect(WidgetThreeDaysSelector.simplifyRoom('P.102'), 'P102');
      expect(WidgetThreeDaysSelector.simplifyRoom('p.204'), 'P204');
      expect(WidgetThreeDaysSelector.simplifyRoom('B205 (SBD 0123)'), 'B205');
      expect(WidgetThreeDaysSelector.simplifyRoom('Lab3'), 'Lab3');
      expect(WidgetThreeDaysSelector.simplifyRoom('Sân A'), 'Sân A');
      expect(WidgetThreeDaysSelector.simplifyRoom('  P.H302  '), 'PH302');
      expect(WidgetThreeDaysSelector.simplifyRoom(''), '');
    });

    test('Mỗi thẻ có 2 dòng: Dòng 1 "HH:mm · phòng", Dòng 2 shortName', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final card1 = data.columns[0].visibleCards[0];

      expect(card1.timeRoomLine, '09:45 · B205');
      expect(card1.shortName, 'Thi PPL NCKH');

      final card2 = data.columns[0].visibleCards[1];
      expect(card2.timeRoomLine, '12:55 · P102');
      expect(card2.shortName, 'CTDL & GT 2');
    });
  });

  group('4. Cột hôm nay: Bỏ môn đã qua & Môn đang học có viền accent (SPEC Mục 3.3 & 5.2)', () {
    test('Môn Tiết 1-3 (06:55-09:20) đã kết thúc bị bỏ qua khỏi vùng hiển thị cột hôm nay', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final todayCards = data.columns[0].visibleCards;

      // Không xuất hiện môn Lập trình Web trong 2 thẻ
      for (final c in todayCards) {
        expect(c.session.id != 101, isTrue);
      }
    });

    test('Môn đang diễn ra tại 10:05 mang cờ isCurrent == true', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      final cardExam = data.columns[0].visibleCards[0];

      expect(cardExam.session.id, 102); // PPL NCKH
      expect(cardExam.isCurrent, isTrue);

      final cardNext = data.columns[0].visibleCards[1];
      expect(cardNext.session.id, 103);
      expect(cardNext.isCurrent, isFalse);
    });

    test('Ngày mai và ngày kia môn chưa diễn ra -> isCurrent == false', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      for (final c in data.columns[1].visibleCards) {
        expect(c.isCurrent, isFalse);
      }
      for (final c in data.columns[2].visibleCards) {
        expect(c.isCurrent, isFalse);
      }
    });
  });

  group('5. Quy tắc ưu tiên lịch thi (AC-11)', () {
    test('Lịch thi luôn được ưu tiên vào vùng hiển thị dù ở mốc giờ muộn hơn ca học', () {
      // Tạo ngày có 1 ca học sớm (06:55) và 1 ca học (09:45) và 1 ca thi muộn (15:30)
      final earlyClass = Session(
        id: 501,
        kind: SessionKind.classSession,
        subjectName: 'Môn Sớm',
        shortName: 'Sớm',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 6, 55),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 9, 20),
        room: 'P.101',
        colorIndex: 0,
      );
      final midClass = Session(
        id: 502,
        kind: SessionKind.classSession,
        subjectName: 'Môn Giữa',
        shortName: 'Giữa',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 9, 45),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 11, 45),
        room: 'P.102',
        colorIndex: 1,
      );
      final lateExam = Session(
        id: 503,
        kind: SessionKind.examSession,
        subjectName: 'Thi Cuối Kỳ',
        shortName: 'Thi CK',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 15, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 17, 30),
        room: 'B201',
        colorIndex: 7,
      );

      final snap = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [earlyClass, midClass, lateExam],
      );

      // Xem ngày mai (T5 29/10)
      final col = WidgetThreeDaysSelector.selectColumn(snapshot: snap, now: now1005, dayOffset: 1);

      expect(col.visibleCards.length, 3);
      // Ca thi muộn 15:30 BẮT BUỘC có mặt trong các thẻ hiển thị
      expect(col.visibleCards.any((c) => c.session.id == 503 && c.isExam), isTrue);
      expect(col.hiddenCount, 0);
    });

    test('Hai ca thi trong ngày chiếm trọn 2 thẻ hiển thị', () {
      final exam1 = Session(
        id: 601,
        kind: SessionKind.examSession,
        subjectName: 'Thi Môn 1',
        shortName: 'Thi 1',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 7, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 9, 30),
        room: 'B101',
        colorIndex: 0,
      );
      final exam2 = Session(
        id: 602,
        kind: SessionKind.examSession,
        subjectName: 'Thi Môn 2',
        shortName: 'Thi 2',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 13, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 15, 30),
        room: 'B102',
        colorIndex: 1,
      );
      final class1 = Session(
        id: 603,
        kind: SessionKind.classSession,
        subjectName: 'Học Chiều',
        shortName: 'Học C',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 15, 30),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 29, 17, 30),
        room: 'P.103',
        colorIndex: 2,
      );

      final snap = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [exam1, exam2, class1],
      );

      final col = WidgetThreeDaysSelector.selectColumn(snapshot: snap, now: now1005, dayOffset: 1);
      expect(col.visibleCards.length, 3);
      expect(col.visibleCards.where((c) => c.isExam).length, 2);
      expect(col.hiddenCount, 0);
    });
  });

  group('6. Cột trống & Trạng thái trống chuẩn (Mục 3.3, 3.6 & AC-10)', () {
    test('Cột ngày không có lịch -> isEmpty == true, emptyText == "Trống"', () {
      // Snapshot chỉ có lịch hôm nay 28/10, ngày 29 và 30 trống
      final snapOnlyToday = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamPpl],
      );

      final data = WidgetThreeDaysSelector.select(snapshot: snapOnlyToday, now: now1005);
      expect(data.columns[0].isEmpty, isFalse);
      expect(data.columns[1].isEmpty, isTrue);
      expect(data.columns[1].emptyText, 'Trống');
      expect(data.columns[2].isEmpty, isTrue);
      expect(data.columns[2].emptyText, 'Trống');
    });

    test('Cột hôm nay khi tất cả môn đã kết thúc -> isEmpty == true, emptyText == "Trống"', () {
      // Giả sử bây giờ là 18:00 (sau khi tất cả 4 môn đã xong)
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1800);

      expect(data.columns[0].isEmpty, isTrue);
      expect(data.columns[0].emptyText, 'Trống');
    });

    test('Chưa có bản chụp -> hasSnapshot == false, authMessage == "Đăng nhập để xem lịch"', () {
      final dataNull = WidgetThreeDaysSelector.select(snapshot: null, now: now1005);
      expect(dataNull.hasSnapshot, isFalse);
      expect(dataNull.authMessage, 'Đăng nhập để xem lịch');
      expect(dataNull.columns.length, 3);
      expect(dataNull.columns[0].title, 'Hôm nay 28');
    });
  });

  group('7. Mốc kiểm thử chuẩn Spec 28/10/2026 10:05 (Mục 5.2)', () {
    test('Xác thực trọn vẹn kết quả mong đợi Mục 5.2', () {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);

      // Cột hôm nay: "Hôm nay 28", sức chứa 4 thẻ -> hiển thị cả 3 môn
      final colToday = data.columns[0];
      expect(colToday.title, 'Hôm nay 28');
      expect(colToday.badgeText, isNull);
      expect(colToday.visibleCards.length, 3);
      expect(colToday.visibleCards[0].timeRoomLine, '09:45 · B205');
      expect(colToday.visibleCards[0].shortName, 'Thi PPL NCKH');
      expect(colToday.visibleCards[0].isExam, isTrue);
      expect(colToday.visibleCards[0].isCurrent, isTrue); // viền accent

      expect(colToday.visibleCards[1].timeRoomLine, '12:55 · P102');
      expect(colToday.visibleCards[1].shortName, 'CTDL & GT 2');
      expect(colToday.visibleCards[1].isExam, isFalse);

      // Cột T5: "T5 · 29", không có nhãn cộng (bỏ +0)
      final colT5 = data.columns[1];
      expect(colT5.title, 'T5 · 29');
      expect(colT5.badgeText, isNull);
      expect(colT5.visibleCards.length, 2);
      expect(colT5.visibleCards[0].timeRoomLine, '06:55 · P204');
      expect(colT5.visibleCards[0].shortName, 'Mạng máy tính');
      expect(colT5.visibleCards[1].timeRoomLine, '12:55 · Sân A');
      expect(colT5.visibleCards[1].shortName, 'Thể dục');

      // Cột T6: "T6 · 30", hiển thị 1 thẻ, không có nhãn cộng
      final colT6 = data.columns[2];
      expect(colT6.title, 'T6 · 30');
      expect(colT6.badgeText, isNull);
      expect(colT6.visibleCards.length, 1);
      expect(colT6.visibleCards[0].timeRoomLine, '12:55 · Lab3');
      expect(colT6.visibleCards[0].shortName, 'Đồ án CN');
    });
  });

  group('8. Mốc cập nhật trạng thái tiếp theo cho AlarmManager & Timeline (Mục 4.3)', () {
    test('getNextTransitionTime tính chính xác mốc chuyển trạng thái tiếp theo tại 10:05', () {
      // Tại 10:05, môn PPL NCKH kết thúc lúc 11:45 -> mốc tiếp theo phải là 11:45
      final nextTime = WidgetThreeDaysSelector.getNextTransitionTime(snapshot: fullSnapshot, now: now1005);
      final nextVn = WidgetTimeUtils.toVnDateTime(nextTime);

      expect(nextVn.hour, 11);
      expect(nextVn.minute, 45);
    });

    test('getAllDayTransitionTimes sinh đầy đủ mốc bắt đầu, kết thúc và nửa đêm', () {
      final transitions = WidgetThreeDaysSelector.getAllDayTransitionTimes(snapshot: fullSnapshot, now: now1005);

      expect(transitions.length >= 3, isTrue);
      // Chứa mốc nửa đêm ngày hôm sau
      final midnightVn = WidgetTimeUtils.nextVnMidnight(now1005);
      expect(transitions.any((t) => t.millisecondsSinceEpoch == midnightVn.millisecondsSinceEpoch), isTrue);
    });
  });

  group('9. Kiểm định AC-08: Zero Hardcoded Time Strings trong mã nguồn Bước 4', () {
    test('Không có mốc giờ cố định \\b\\d{1,2}:\\d{2}\\b trong mã nguồn widget Bước 4', () {
      final step4Files = [
        'lib/services/widget/widget_three_days_selector.dart',
        'lib/widgets/widget_three_days_4x2_card.dart',
        'android/app/src/main/kotlin/com/tramkien/hau/ThreeDaysScheduleWidgetProvider.kt',
        'android/app/src/main/res/layout/widget_schedule_three_days.xml',
        'android/app/src/main/res/xml/widget_schedule_three_days_info.xml',
      ];

      final regex = RegExp(r'\b\d{1,2}:\d{2}\b');

      for (final filePath in step4Files) {
        final file = File(filePath);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final cleanLine = line.trim();

          // Bỏ qua chú thích code
          if (cleanLine.startsWith('//') || cleanLine.startsWith('*') || cleanLine.startsWith('/*')) {
            continue;
          }

          final match = regex.firstMatch(line);
          if (match != null) {
            fail('Phát hiện hardcode mốc giờ "${match.group(0)}" tại $filePath dòng \${i + 1}: \$line');
          }
        }
      }
    });
  });

  group('10. Widget Test: Render Widget Lịch 3 ngày 4x2 (Flutter Parity Card)', () {
    testWidgets('Render chuẩn mốc Spec 28/10/2026 10:05: 3 Cột, tiêu đề, thẻ môn, badge +1', (tester) async {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetThreeDays4x2Card(
                data: data,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      // Tìm tiêu đề 3 cột
      expect(find.text('Hôm nay 28'), findsOneWidget);
      expect(find.text('T5 · 29'), findsOneWidget);
      expect(find.text('T6 · 30'), findsOneWidget);

      // Cột hôm nay có 3 môn hiển thị đủ cả 3 nên không có badge +1
      expect(find.text('+1'), findsNothing);

      // Tuyệt đối không có "+0"
      expect(find.text('+0'), findsNothing);

      // Thẻ môn cột hôm nay
      expect(find.text('09:45 · B205'), findsOneWidget);
      expect(find.text('Thi PPL NCKH'), findsOneWidget);
      expect(find.text('12:55 · P102'), findsOneWidget);
      expect(find.text('CTDL & GT 2'), findsOneWidget);

      // Thẻ môn cột T5
      expect(find.text('06:55 · P204'), findsOneWidget);
      // 'Mạng máy tính' xuất hiện ở cả hôm nay (15:30) và T5 (06:55)
      expect(find.text('Mạng máy tính'), findsNWidgets(2));
      expect(find.text('12:55 · Sân A'), findsOneWidget);
      expect(find.text('Thể dục'), findsOneWidget);

      // Thẻ môn cột T6
      expect(find.text('12:55 · Lab3'), findsOneWidget);
      expect(find.text('Đồ án CN'), findsOneWidget);
    });

    testWidgets('Render Dark mode chính xác theo Token', (tester) async {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetThreeDays4x2Card(
                data: data,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hôm nay 28'), findsOneWidget);
      expect(find.text('Thi PPL NCKH'), findsOneWidget);
    });

    testWidgets('Render trạng thái trống "Đăng nhập để xem lịch"', (tester) async {
      final dataNull = WidgetThreeDaysSelector.select(snapshot: null, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetThreeDays4x2Card(
                data: dataNull,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đăng nhập để xem lịch'), findsOneWidget);
    });

    testWidgets('Render cột "Trống" khi ngày không có lịch', (tester) async {
      // Chỉ có lịch hôm nay, ngày 29 và 30 trống
      final snapOnlyToday = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamPpl],
      );
      final data = WidgetThreeDaysSelector.select(snapshot: snapOnlyToday, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetThreeDays4x2Card(
                data: data,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      // 2 cột T5 và T6 trống -> hiển thị 2 nhãn "Trống"
      expect(find.text('Trống'), findsNWidgets(2));
    });

    testWidgets('Hỗ trợ tap callback trên Card và trên Cột', (tester) async {
      final data = WidgetThreeDaysSelector.select(snapshot: fullSnapshot, now: now1005);
      ThreeDaysCardItem? tappedCard;
      ThreeDaysColumnData? tappedCol;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetThreeDays4x2Card(
                data: data,
                isDarkMode: false,
                onCardTap: (c) => tappedCard = c,
                onColumnTap: (col) => tappedCol = col,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Thi PPL NCKH'));
      await tester.pump();
      expect(tappedCard, isNotNull);
      expect(tappedCard?.session.id, 102);

      await tester.tap(find.text('T5 · 29'));
      await tester.pump();
      expect(tappedCol, isNotNull);
      expect(tappedCol?.dateIso, '2026-10-29');
    });
  });
}
