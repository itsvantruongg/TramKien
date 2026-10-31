import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/widgets/widget_lock_screen_cards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mốc chuẩn Spec: 28/10/2026 (Thứ Tư)
  final testYear = 2026;
  final testMonth = 10;
  final testDay = 28;

  // Phiên mẫu 1: Lập trình Web (06:55 - 09:20 VN) -> past tại 10:05
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

  // Phiên mẫu 2: Thi PPL NCKH (09:45 - 11:45 VN, 120 phút, endEstimated = false) -> current tại 10:05
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

  // Phiên mẫu 3: Cấu trúc dữ liệu và giải thuật 2 (12:55 - 15:25 VN) -> upcoming tại 10:05
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

  // Phiên mẫu 4: Mạng máy tính (15:30 - 17:05 VN) -> upcoming tại 10:05
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

  group('1. Mốc kiểm thử chuẩn Spec 28/10/2026 10:05 (Mục 5.2 & Mục 3.5)', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('Rectangular: Dòng 1 "Đang thi · 09:45", Dòng 2 PPL NCKH, Dòng 3 "B205 · còn 100 phút"', () {
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: fullSnapshot, now: now1005);

      expect(rect.stateType, LockScreenStateType.sessionActive);
      expect(rect.isExam, isTrue);
      expect(rect.endEstimated, isFalse);
      expect(rect.line1, 'Đang thi · 09:45');
      expect(rect.line2, 'PPL NCKH');
      // 11:45 - 10:05 = 100 phút còn lại, phòng B205 (SBD 0123) rút gọn thành B205
      expect(rect.line3, 'B205 · còn 100 phút');
      expect(rect.deepLinkUri, contains('sessionId=102'));
    });

    test('Circular: Giờ giữa là môn kế tiếp "12:55", Gauge tiến độ ~0.17 (16.7%)', () {
      final circ = WidgetLockScreenSelector.selectCircular(snapshot: fullSnapshot, now: now1005);

      expect(circ.hasActiveSession, isTrue);
      // Môn kế tiếp hôm nay là CTDL & GT 2 (12:55)
      expect(circ.centerText, '12:55');
      // 09:45 đến 11:45 = 120 phút. Tại 10:05 đã qua 20 phút -> 20/120 ~ 16.7%
      expect((circ.progress * 100).toStringAsFixed(1), '16.7');
      expect(circ.progress, closeTo(0.167, 0.005));
    });

    test('Inline: "09:45 PPL NCKH · B205"', () {
      final inline = WidgetLockScreenSelector.selectInline(snapshot: fullSnapshot, now: now1005);

      expect(inline.text, '09:45 PPL NCKH · B205');
      expect(inline.session?.id, 102);
    });
  });

  group('2. Kiểm định accessoryRectangular: Đang học / Đang thi / Tiếp theo & Quy tắc endEstimated', () {
    test('Ca học đang diễn ra: Dòng 1 "Đang học · HH:mm", Dòng 3 "phòng · còn N phút"', () {
      final now0715 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 7, 15);
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: fullSnapshot, now: now0715);

      expect(rect.stateType, LockScreenStateType.sessionActive);
      expect(rect.isExam, isFalse);
      expect(rect.line1, 'Đang học · 06:55');
      expect(rect.line2, 'LT Web');
      // 09:20 - 07:15 = 125 phút còn lại
      expect(rect.line3, 'P301 · còn 125 phút');
    });

    test('QUY TẮC ĐẶC BIỆT: Ca thi có endEstimated = true: Chỉ Dòng 1 và Dòng 2, BỎ DÒNG 3', () {
      final snapWithEstimated = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamEstimated],
      );
      // 14:15 VN -> ca thi 14:00 đang diễn ra
      final now1415 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 14, 15);
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: snapWithEstimated, now: now1415);

      expect(rect.stateType, LockScreenStateType.sessionActive);
      expect(rect.isExam, isTrue);
      expect(rect.endEstimated, isTrue);
      expect(rect.line1, 'Đang thi · 14:00');
      expect(rect.line2, 'TA CN');
      // BỎ DÒNG 3 "còn N phút"
      expect(rect.line3, isNull);
    });

    test('Chưa có ca đang diễn ra: Dòng 1 "Tiếp theo · HH:mm", Dòng 3 "phòng · còn N phút"', () {
      // 12:00 VN: sau khi thi PPL NCKH xong (11:45), ca tiếp theo là CTDL & GT 2 (12:55)
      final now1200 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 0);
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: fullSnapshot, now: now1200);

      expect(rect.stateType, LockScreenStateType.sessionActive);
      expect(rect.line1, 'Tiếp theo · 12:55');
      expect(rect.line2, 'CTDL & GT 2');
      // 12:55 - 12:00 = 55 phút
      expect(rect.line3, 'P102 · còn 55 phút');
    });
  });

  group('3. Kiểm định accessoryCircular: Giờ giữa, Gauge tiến độ & Fallback ngày mai', () {
    test('Không có ca đang học: Gauge tiến độ = 0.0, giờ giữa là môn kế tiếp', () {
      final now1200 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 0);
      final circ = WidgetLockScreenSelector.selectCircular(snapshot: fullSnapshot, now: now1200);

      expect(circ.hasActiveSession, isFalse);
      expect(circ.progress, 0.0);
      expect(circ.centerText, '12:55');
    });

    test('Ca thi có endEstimated = true: Gauge tiến độ rỗng (0.0)', () {
      final snapWithEstimated = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionExamEstimated],
      );
      final now1415 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 14, 15);
      final circ = WidgetLockScreenSelector.selectCircular(snapshot: snapWithEstimated, now: now1415);

      expect(circ.hasActiveSession, isTrue);
      // Rỗng khi ca thi có endEstimated = true
      expect(circ.progress, 0.0);
    });

    test('Hết môn trong ngày: Giờ giữa hiển thị giờ môn ngày mai (06:55)', () {
      // 18:00 VN: đã hết môn hôm nay, ngày mai có môn lúc 06:55
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final circ = WidgetLockScreenSelector.selectCircular(snapshot: fullSnapshot, now: now1800);

      expect(circ.progress, 0.0);
      expect(circ.centerText, '06:55');
    });

    test('Hôm nay và ngày mai đều không có môn: Giờ giữa hiển thị dấu gạch "--:--"', () {
      final emptySnap = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [],
      );
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final circ = WidgetLockScreenSelector.selectCircular(snapshot: emptySnap, now: now1800);

      expect(circ.progress, 0.0);
      expect(circ.centerText, '--:--');
    });
  });

  group('4. Kiểm định accessoryInline: Định dạng, môn kế tiếp & Trạng thái trống', () {
    test('Ca sắp tới trong ngày: "HH:mm ShortName · phòng"', () {
      final now1200 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 12, 0);
      final inline = WidgetLockScreenSelector.selectInline(snapshot: fullSnapshot, now: now1200);

      expect(inline.text, '12:55 CTDL & GT 2 · P102');
    });

    test('Khi hết môn trong ngày: "Không có lịch hôm nay"', () {
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final inline = WidgetLockScreenSelector.selectInline(snapshot: fullSnapshot, now: now1800);

      expect(inline.text, 'Không có lịch hôm nay');
    });

    test('Hôm nay hoàn toàn trống: "Không có lịch hôm nay"', () {
      final emptySnap = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [],
      );
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final inline = WidgetLockScreenSelector.selectInline(snapshot: emptySnap, now: now1005);

      expect(inline.text, 'Không có lịch hôm nay');
    });
  });

  group('5. Kiểm định các trạng thái trống (Chưa đăng nhập / DB rỗng / Hết ngày)', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('Chưa đăng nhập / snapshot == null: "Đăng nhập để xem lịch"', () {
      final data = WidgetLockScreenSelector.select(snapshot: null, now: now1005);

      expect(data.rectangular.stateType, LockScreenStateType.noSnapshot);
      expect(data.rectangular.line1, 'Đăng nhập để xem lịch');
      expect(data.rectangular.line2, '');
      expect(data.rectangular.line3, isNull);

      expect(data.circular.centerText, '--:--');
      expect(data.circular.progress, 0.0);

      expect(data.inline.text, 'Đăng nhập để xem lịch');
    });

    test('Hôm nay không có lịch: Rectangular "Hôm nay không có lịch" + ca kế tiếp trong 7 ngày', () {
      // Snapshot chỉ có ca ngày mai
      final snapTomorrowOnly = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionTomorrow],
      );
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: snapTomorrowOnly, now: now1005);

      expect(rect.stateType, LockScreenStateType.emptyDay);
      expect(rect.line1, 'Hôm nay không có lịch');
      expect(rect.line2, contains('Tiếp theo: T5 06:55 Mạng máy tính'));
      expect(rect.line3, isNull);
    });

    test('Hết ngày (đã hoàn thành tất cả các ca): Rectangular "Hôm nay đã xong N môn"', () {
      final now1800 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 18, 0);
      final rect = WidgetLockScreenSelector.selectRectangular(snapshot: fullSnapshot, now: now1800);

      expect(rect.stateType, LockScreenStateType.allFinished);
      expect(rect.line1, 'Hôm nay đã xong 4 môn');
      expect(rect.line2, contains('Tiếp theo: T5 06:55 Mạng máy tính'));
      expect(rect.line3, isNull);
    });
  });

  group('6. Kiểm định Android Lock Screen Configuration & Contrast Invariants', () {
    test('widget_schedule_single_day_2x2_info.xml không khai báo not_keyguard', () {
      final infoFile = File('android/app/src/main/res/xml/widget_schedule_single_day_2x2_info.xml');
      expect(infoFile.existsSync(), isTrue);

      final content = infoFile.readAsStringSync();
      expect(content.contains('not_keyguard'), isFalse,
          reason: 'Không được khai báo not_keyguard để hỗ trợ lock screen / hub mode Android 15/16 QPR1');
      expect(content.contains('android:widgetCategory="home_screen"'), isTrue);
    });

    test('AndroidManifest.xml không đặt cờ showWhenLocked trên MainActivity', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:showWhenLocked="true"'), isFalse,
          reason: 'MainActivity không được đặt showWhenLocked để yêu cầu mở khóa trước khi vào app');
    });

    test('Layout Android 2x2 định nghĩa TextView tương phản cao cho lock screen', () {
      final layoutFile = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(layoutFile.existsSync(), isTrue);

      final content = layoutFile.readAsStringSync();
      expect(content.contains('@color/widget_text_primary'), isTrue);
      expect(content.contains('@color/widget_text_secondary'), isTrue);
    });
  });

  group('7. Kiểm định AC-08: Zero Hardcoded Time Strings trong toàn bộ mã nguồn Bước 6', () {
    test('Không có mốc giờ cố định \\b\\d{1,2}:\\d{2}\\b trong toàn bộ mã nguồn Bước 6', () {
      final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

      final filesToCheck = [
        'lib/services/widget/widget_lock_screen_selector.dart',
        'lib/widgets/widget_lock_screen_cards.dart',
        'ios/Runner/ScheduleWidgetKit.swift',
        'android/app/src/main/res/xml/widget_schedule_single_day_2x2_info.xml',
      ];

      for (final relPath in filesToCheck) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'File $relPath phải tồn tại');

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();

          // Bỏ qua dòng chú thích
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('<!--')) {
            continue;
          }

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

  group('8. Widget Tests: Render các Thẻ Mô phỏng Lock Screen Monochrome (Live Preview)', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
    final data = WidgetLockScreenSelector.select(snapshot: fullSnapshot, now: now1005);

    testWidgets('Render WidgetLockScreenRectangularCard chuẩn mốc Spec', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetLockScreenRectangularCard(data: data.rectangular),
            ),
          ),
        ),
      );

      expect(find.text('Đang thi · 09:45'), findsOneWidget);
      expect(find.text('PPL NCKH'), findsOneWidget);
      expect(find.text('B205 · còn 100 phút'), findsOneWidget);
    });

    testWidgets('Render WidgetLockScreenCircularCard chuẩn mốc Spec', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetLockScreenCircularCard(data: data.circular),
            ),
          ),
        ),
      );

      expect(find.text('12:55'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Render WidgetLockScreenInlineCard chuẩn mốc Spec', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetLockScreenInlineCard(data: data.inline),
            ),
          ),
        ),
      );

      expect(find.text('09:45 PPL NCKH · B205'), findsOneWidget);
    });

    testWidgets('Render WidgetLockScreenPreviewSet hiển thị toàn bộ 3 widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetLockScreenPreviewSet(data: data),
            ),
          ),
        ),
      );

      expect(find.text('MÀN HÌNH KHÓA (LOCK SCREEN)'), findsOneWidget);
      expect(find.text('Đang thi · 09:45'), findsOneWidget);
      expect(find.text('12:55'), findsOneWidget);
      expect(find.text('09:45 PPL NCKH · B205'), findsOneWidget);
    });

    testWidgets('Render Light wallpaper mode không ném ngoại lệ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetLockScreenPreviewSet(
                data: data,
                isLightWallpaper: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đang thi · 09:45'), findsOneWidget);
    });

    testWidgets('Hỗ trợ onTap callback trên các thẻ lock screen', (tester) async {
      var rectTapped = false;
      var circTapped = false;
      var inlineTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WidgetLockScreenRectangularCard(
                  data: data.rectangular,
                  onTap: () => rectTapped = true,
                ),
                WidgetLockScreenCircularCard(
                  data: data.circular,
                  onTap: () => circTapped = true,
                ),
                WidgetLockScreenInlineCard(
                  data: data.inline,
                  onTap: () => inlineTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(WidgetLockScreenRectangularCard));
      expect(rectTapped, isTrue);

      await tester.tap(find.byType(WidgetLockScreenCircularCard));
      expect(circTapped, isTrue);

      await tester.tap(find.byType(WidgetLockScreenInlineCard));
      expect(inlineTapped, isTrue);
    });
  });
}
