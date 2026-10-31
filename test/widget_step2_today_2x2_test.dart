import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/widgets/widget_today_2x2_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mốc chuẩn Spec: 28/10/2026 (Thứ Tư)
  // Các mốc giờ kiểm thử (dùng các biến số động, không hardcode)
  const testYear = 2026;
  const testMonth = 10;
  const testDay = 28;

  // Phiên mẫu 1: Lập trình Web (06:55 - 09:20 VN)
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

  // Phiên mẫu 2: Thi PPL NCKH (09:45 - 11:45 VN, 120 phút, endEstimated = false)
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

  // Phiên mẫu 3: Cấu trúc dữ liệu và giải thuật 2 (12:55 - 15:25 VN)
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

  // Phiên mẫu 4: Mạng máy tính (15:30 - 17:05 VN)
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

  // Phiên ngày mai: 29/10/2026 Mạng máy tính (06:55 - 09:20 VN)
  final sessionTomorrow = Session(
    id: 201,
    kind: SessionKind.classSession,
    subjectName: 'Mạng máy tính',
    shortName: 'Mạng máy tính',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 1, 9, 20),
    room: 'P.204',
    colorIndex: 3,
    endEstimated: false,
  );

  // Phiên thi có endEstimated = true (ước tính 90 phút)
  final sessionExamEstimated = Session(
    id: 301,
    kind: SessionKind.examSession,
    subjectName: 'Thi Tiếng Anh chuyên ngành',
    shortName: 'TA CN',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 14, 0),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 15, 30),
    room: 'B101',
    colorIndex: 1,
    endEstimated: true,
  );

  final fullSnapshot = WidgetScheduleSnapshot(
    version: 1,
    generatedAt: DateTime.now().millisecondsSinceEpoch,
    sessions: [sessionWeb, sessionExamPpl, sessionCtdl2, sessionNetwork, sessionTomorrow],
  );

  group('1. Thứ tự ưu tiên chọn môn cho Widget 2x2 (Mục 3.1 & 3.6)', () {
    test('Ưu tiên 1: Đang thi tại mốc 10:05 VN (Ca thi đang diễn ra)', () {
      // 28/10/2026 10:05 VN (sessionWeb đã qua, sessionExamPpl đang diễn ra)
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1005);

      expect(data.stateType, Today2x2StateType.sessionActive);
      expect(data.statusLabel, 'Đang thi');
      expect(data.isExam, isTrue);
      expect(data.subjectName, sessionExamPpl.subjectName);
      expect(data.subInfo, contains('B205'));
      expect(data.showProgressBar, isTrue);
      // Bắt đầu 09:45, kết thúc 11:45 (120 phút). Đã qua 20 phút -> 20/120 ~ 16.7%
      expect((data.progress * 100).toStringAsFixed(1), '16.7');
      expect(data.countdownAndroid, contains('11:45'));
      expect(data.countdownIos, contains('100 phút'));
      expect(data.deepLinkUri, contains('sessionId=102'));
    });

    test('Ưu tiên 1: Đang học tại mốc 07:15 VN (Ca học thông thường đang diễn ra)', () {
      final now0715 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 7, 15);

      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now0715);

      expect(data.stateType, Today2x2StateType.sessionActive);
      expect(data.statusLabel, 'Đang học');
      expect(data.isExam, isFalse);
      expect(data.subjectName, 'Lập trình Web');
      expect(data.subInfo, contains('P.301'));
      expect(data.showProgressBar, isTrue);
      // Bắt đầu 06:55, kết thúc 09:20 (145 phút). Đã qua 20 phút -> 20/145 ~ 13.8%
      expect((data.progress * 100).toStringAsFixed(1), '13.8');
      expect(data.countdownAndroid, contains('09:20'));
      expect(data.countdownIos, contains('125 phút'));
    });

    test('Ưu tiên 1 khi endEstimated = true: Ẩn thanh tiến độ và dòng đếm ngược', () {
      final snapshotEstimated = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamEstimated],
      );

      final now1420 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 14, 20);
      final data = WidgetToday2x2Selector.select(snapshot: snapshotEstimated, now: now1420);

      expect(data.statusLabel, 'Đang thi');
      expect(data.isExam, isTrue);
      expect(data.endEstimated, isTrue);
      // Quy chuẩn Mục 3.1 & 4.1: Nếu endEstimated = true: ẩn thanh tiến độ và ẩn dòng đếm ngược
      expect(data.showProgressBar, isFalse);
      expect(data.progress, 0.0);
      expect(data.countdownAndroid, isNull);
      expect(data.countdownIos, isNull);
      expect(data.subInfo, contains('B101'));
    });

    test('Ưu tiên 2: Lịch thi sắp tới trong ngày (kind == exam và upcoming)', () {
      // 28/10/2026 09:30 VN (sessionWeb đã xong lúc 09:20, ca thi sắp bắt đầu lúc 09:45)
      final now0930 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 9, 30);

      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now0930);

      expect(data.stateType, Today2x2StateType.sessionActive);
      expect(data.statusLabel, 'Tiếp theo');
      expect(data.isExam, isTrue);
      expect(data.subjectName, sessionExamPpl.subjectName);
      expect(data.showProgressBar, isFalse);
      expect(data.countdownAndroid, isNull);
    });

    test('Ưu tiên 3: Môn sắp tới gần nhất trong ngày (kind == class và upcoming)', () {
      // 28/10/2026 12:00 VN (ca thi xong 11:45, môn kế tiếp là CTDL & GT 2 lúc 12:55)
      final now1200 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 0);

      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1200);

      expect(data.stateType, Today2x2StateType.sessionActive);
      expect(data.statusLabel, 'Tiếp theo');
      expect(data.isExam, isFalse);
      expect(data.subjectName, contains('Cấu trúc dữ liệu và giải thuật 2'));
      expect(data.showProgressBar, isFalse);
    });

    test('Ưu tiên 4: Hết ngày -> Môn đầu tiên của ngày mai kèm nhãn "Ngày mai"', () {
      // 28/10/2026 18:00 VN (tất cả môn ngày 28 đã qua, ngày 29 có sessionTomorrow)
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);

      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1800);

      expect(data.stateType, Today2x2StateType.sessionActive);
      expect(data.statusLabel, 'Ngày mai');
      expect(data.subjectName, sessionTomorrow.subjectName);
      expect(data.subInfo, contains('P.204'));
      expect(data.showProgressBar, isFalse);
      expect(data.deepLinkUri, contains('sessionId=201'));
    });
  });

  group('2. Bốn trạng thái trống chuẩn (Mục 3.6 & AC-10)', () {
    test('Trạng thái 0: Chưa có bản chụp / chưa đăng nhập -> "Đăng nhập để xem lịch"', () {
      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);

      final nullData = WidgetToday2x2Selector.select(snapshot: null, now: now);
      expect(nullData.stateType, Today2x2StateType.noSnapshot);
      expect(nullData.displayTitle, 'Đăng nhập để xem lịch');

      const invalidSnapshot = WidgetScheduleSnapshot(
        version: 99, // Sai version
        generatedAt: 0,
        sessions: [],
      );
      final invalidData = WidgetToday2x2Selector.select(snapshot: invalidSnapshot, now: now);
      expect(invalidData.stateType, Today2x2StateType.noSnapshot);
      expect(invalidData.displayTitle, 'Đăng nhập để xem lịch');
    });

    test('Trạng thái 1: Hôm nay không có lịch kèm ca tiếp theo trong 7 ngày', () {
      final futureSession = Session(
        id: 401,
        kind: SessionKind.classSession,
        subjectName: 'Mạng máy tính',
        shortName: 'Mạng máy tính',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 3, 6, 55),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay + 3, 9, 20),
        room: 'P.204',
        colorIndex: 3,
      );

      final emptyTodaySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [futureSession],
      );

      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);
      final data = WidgetToday2x2Selector.select(snapshot: emptyTodaySnapshot, now: now);

      expect(data.stateType, Today2x2StateType.emptyDay);
      expect(data.displayTitle, 'Hôm nay không có lịch');
      // Kèm thông tin ca tiếp theo: "Tiếp theo: <thứ> HH:mm <tên môn>"
      expect(data.subInfo, startsWith('Tiếp theo: '));
      expect(data.subInfo, contains('Mạng máy tính'));
    });

    test('Trạng thái 1: Hôm nay không có lịch và 7 ngày tới hoàn toàn trống', () {
      final emptySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [],
      );

      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);
      final data = WidgetToday2x2Selector.select(snapshot: emptySnapshot, now: now);

      expect(data.stateType, Today2x2StateType.emptyDay);
      expect(data.displayTitle, 'Hôm nay không có lịch');
      expect(data.subInfo, 'Không có lịch sắp tới');
    });

    test('Trạng thái 2: Đã kết thúc toàn bộ ca học trong ngày (ngày mai không có lịch)', () {
      final onlyTodaySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionWeb, sessionExamPpl],
      );

      // 28/10/2026 18:00 VN: Cả 2 môn của ngày 28 đều đã qua, ngày mai không có môn
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final data = WidgetToday2x2Selector.select(snapshot: onlyTodaySnapshot, now: now1800);

      expect(data.stateType, Today2x2StateType.allFinished);
      expect(data.displayTitle, 'Hôm nay đã xong 2 môn');
      expect(data.subInfo, 'Không có lịch sắp tới');
    });
  });

  group('3. Quy tắc cắt tên dài bảo tồn hậu tố (AC-09) trên 2x2', () {
    test('Bảo tồn hậu tố số 2 khi cắt giữa tên môn dài', () {
      const original = 'Cấu trúc dữ liệu và giải thuật 2';
      final formatted = WidgetHashUtils.formatWithEllipsisPreservation(original, maxLength: 24);

      expect(formatted.endsWith('2'), isTrue);
      expect(formatted.contains('…'), isTrue);
      expect(formatted.length, lessThanOrEqualTo(24));
    });

    test('Bảo tồn hậu tố chữ số La Mã khi cắt giữa', () {
      const original = 'Toán ứng dụng cho kỹ sư CNTT III';
      final formatted = WidgetHashUtils.formatWithEllipsisPreservation(original, maxLength: 22);

      expect(formatted.endsWith('III'), isTrue);
      expect(formatted.contains('…'), isTrue);
      expect(formatted.length, lessThanOrEqualTo(22));
    });

    test('Tên ngắn giữ nguyên không bị chèn dấu ba chấm', () {
      const shortName = 'Thể dục';
      expect(WidgetHashUtils.formatWithEllipsisPreservation(shortName, maxLength: 24), shortName);
    });
  });

  group('4. Tính mốc đổi trạng thái tiếp theo cho AlarmManager & Timeline (Mục 4.3)', () {
    test('getNextTransitionTime tính chính xác mốc chuyển trạng thái tiếp theo', () {
      // Tại 07:00 VN, môn Web kết thúc lúc 09:20 VN -> mốc kế tiếp là 09:20
      final now0700 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 7, 0);
      final nextTransition = WidgetToday2x2Selector.getNextTransitionTime(
        snapshot: fullSnapshot,
        now: now0700,
      );

      final vnNext = WidgetTimeUtils.toVnDateTime(nextTransition);
      expect(vnNext.hour, 9);
      expect(vnNext.minute, 20);

      // Tại 10:05 VN, ca thi kết thúc lúc 11:45 VN -> mốc kế tiếp là 11:45
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final nextExamTransition = WidgetToday2x2Selector.getNextTransitionTime(
        snapshot: fullSnapshot,
        now: now1005,
      );
      final vnExamNext = WidgetTimeUtils.toVnDateTime(nextExamTransition);
      expect(vnExamNext.hour, 11);
      expect(vnExamNext.minute, 45);

      // Tại 20:00 VN (hết môn), mốc tiếp theo là 00:00 sang ngày mới 29/10
      final now2000 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 20, 0);
      final nextMidnightTransition = WidgetToday2x2Selector.getNextTransitionTime(
        snapshot: fullSnapshot,
        now: now2000,
      );
      final vnMidnight = WidgetTimeUtils.toVnDateTime(nextMidnightTransition);
      expect(vnMidnight.day, testDay + 1);
      expect(vnMidnight.hour, 0);
      expect(vnMidnight.minute, 0);
    });

    test('getAllDayTransitionTimes sinh đầy đủ mốc bắt đầu, kết thúc và nửa đêm', () {
      final date = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 0, 0);
      final allTimes = WidgetToday2x2Selector.getAllDayTransitionTimes(
        snapshot: fullSnapshot,
        date: date,
      );

      // Có 4 môn trong ngày (mỗi môn có start và end) + mốc 00:00 ngày hôm sau
      // Tổng cộng 9 mốc thời gian không trùng
      expect(allTimes.length, greaterThanOrEqualTo(8));
      // Mốc cuối cùng phải là 00:00 ngày hôm sau
      final last = WidgetTimeUtils.toVnDateTime(allTimes.last);
      expect(last.day, testDay + 1);
      expect(last.hour, 0);
      expect(last.minute, 0);
    });
  });

  group('5. Deep link chuẩn xác (AC-07)', () {
    test('Đúng cú pháp tramkien://schedule kèm tham số ngày và sessionId', () {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1005);

      expect(data.deepLinkUri, startsWith('tramkien://schedule?'));
      expect(data.deepLinkUri, contains('date=2026-10-28'));
      expect(data.deepLinkUri, contains('sessionId=102'));
    });

    test('Deep link cho trạng thái trống trỏ đến ngày hiện tại', () {
      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);
      final emptySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [],
      );
      final data = WidgetToday2x2Selector.select(snapshot: emptySnapshot, now: now);

      expect(data.deepLinkUri, 'tramkien://schedule?date=2026-10-28');
    });
  });

  group('6. Kiểm định AC-08: Zero Hardcoded Time Strings trong mã nguồn Bước 2', () {
    test('Không có mốc giờ cố định \\b\\d{1,2}:\\d{2}\\b trong mã nguồn widget', () {
      final filesToAudit = [
        'android/app/src/main/kotlin/com/tramkien/hau/SingleDay2x2ScheduleWidgetProvider.kt',
        'android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml',
        'android/app/src/main/res/xml/widget_schedule_single_day_2x2_info.xml',
        'ios/Runner/ScheduleWidgetKit.swift',
        'lib/services/widget/widget_today_2x2_selector.dart',
        'lib/widgets/widget_today_2x2_card.dart',
      ];

      final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

      for (final relPath in filesToAudit) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'File $relPath phải tồn tại');

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();

          // Bỏ qua dòng comment
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('<!--')) {
            continue;
          }

          final match = timeRegex.firstMatch(line);
          expect(
            match,
            isNull,
            reason: 'Phát hiện mốc giờ hardcode "${match?.group(0)}" tại file $relPath, dòng ${i + 1}: "$line"',
          );
        }
      }
    });
  });

  group('7. Widget Test: Render Widget Hôm nay 2x2 (Flutter Parity Card)', () {
    testWidgets('Render ca thi đang diễn ra đầy đủ nhãn, thanh tiến độ và đếm ngược', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1005);

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetToday2x2Card(
                data: data,
                isDarkMode: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Xác thực nhãn trạng thái và tên môn
      expect(find.text('Đang thi'), findsOneWidget);
      expect(find.textContaining('B205'), findsOneWidget);
      expect(find.textContaining('11:45'), findsOneWidget);

      // Chạm để kích hoạt deep link callback
      await tester.tap(find.byType(WidgetToday2x2Card));
      expect(tapped, isTrue);
    });

    testWidgets('Render Dark mode chính xác theo Token Mục 1.4 & 1.5', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetToday2x2Selector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: WidgetToday2x2Card(
                data: data,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đang thi'), findsOneWidget);
    });

    testWidgets('Render ca thi endEstimated = true ẩn thanh tiến độ và đếm ngược trên Widget Card', (tester) async {
      final snapshotEstimated = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamEstimated],
      );
      final now1420 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 14, 20);
      final data = WidgetToday2x2Selector.select(snapshot: snapshotEstimated, now: now1420);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetToday2x2Card(
                data: data,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đang thi'), findsOneWidget);
      expect(find.textContaining('B101'), findsOneWidget);
      expect(find.textContaining('Đến'), findsNothing);
      expect(find.textContaining('Còn'), findsNothing);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('Render trạng thái trống "Đăng nhập để xem lịch"', (tester) async {
      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);
      final data = WidgetToday2x2Selector.select(snapshot: null, now: now);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetToday2x2Card(
                data: data,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đăng nhập để xem lịch'), findsOneWidget);
    });

    testWidgets('Render trạng thái trống "Hôm nay không có lịch"', (tester) async {
      final emptySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [],
      );
      final now = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 0);
      final data = WidgetToday2x2Selector.select(snapshot: emptySnapshot, now: now);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetToday2x2Card(
                data: data,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hôm nay không có lịch'), findsOneWidget);
      expect(find.text('Không có lịch sắp tới'), findsOneWidget);
    });
  });
}
