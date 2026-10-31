import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/widgets/widget_weekly_4x4_card.dart';
import 'package:Tram_Kien/widgets/widget_today_2x2_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mốc chuẩn Spec: 28/10/2026 (Thứ Tư, 10:05 AM VN)
  const testYear = 2026;
  const testMonth = 10;
  const testDay = 28;

  // ==================== CÁC PHIÊN THEO BẢNG 5.1 SPEC ====================
  // T2 26/10/2026: 3 môn (06:55, 09:30, 12:55)
  final sessionT2_1 = Session(
    id: 1,
    kind: SessionKind.classSession,
    subjectName: 'Kiểm thử phần mềm',
    shortName: 'KTPM',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 9, 20),
    room: 'P.101',
    colorIndex: 0,
  );
  final sessionT2_2 = Session(
    id: 2,
    kind: SessionKind.classSession,
    subjectName: 'Cơ sở dữ liệu',
    shortName: 'CSDL',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 9, 30),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 11, 55),
    room: 'P.101',
    colorIndex: 1,
  );
  final sessionT2_3 = Session(
    id: 3,
    kind: SessionKind.classSession,
    subjectName: 'Hệ điều hành',
    shortName: 'HDH',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 12, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 26, 15, 25),
    room: 'P.101',
    colorIndex: 2,
  );

  // T3 27/10/2026: 1 môn (06:55 - 09:20)
  final sessionT3 = Session(
    id: 4,
    kind: SessionKind.classSession,
    subjectName: 'Kỹ thuật đồ họa',
    shortName: 'KT Đồ họa',
    start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 27, 6, 55),
    end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 27, 9, 20),
    room: 'P.102',
    colorIndex: 3,
  );

  // T4 28/10/2026 (Hôm nay): 4 môn
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

  // T5 29/10/2026: 2 môn
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

  // T6 30/10/2026: 1 môn
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

  // Snapshot tuần chuẩn theo Bảng 5.1
  final fullSnapshot = WidgetScheduleSnapshot(
    version: 1,
    generatedAt: DateTime.now().millisecondsSinceEpoch,
    sessions: [
      sessionT2_1,
      sessionT2_2,
      sessionT2_3,
      sessionT3,
      sessionWeb,
      sessionExamPpl,
      sessionCtdl2,
      sessionNetwork,
      sessionT5_1,
      sessionT5_2,
      sessionT6,
    ],
  );

  group('1. Kiểm định Tiêu đề Tuần dd/MM – dd/MM & Nút chuyển tuần (weekOffset)', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('Tiêu đề tuần hiện tại (weekOffset = 0): Tuần 26/10 – 01/11', () {
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005, weekOffset: 0);
      expect(data.title, 'Tuần 26/10 \u2013 01/11');
      expect(data.weekOffset, 0);
    });

    test('Tiêu đề tuần kế tiếp (weekOffset = 1): Tuần 02/11 – 08/11', () {
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005, weekOffset: 1);
      expect(data.title, 'Tuần 02/11 \u2013 08/11');
      expect(data.weekOffset, 1);
    });

    test('Tiêu đề tuần trước đó (weekOffset = -1): Tuần 19/10 – 25/10', () {
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005, weekOffset: -1);
      expect(data.title, 'Tuần 19/10 \u2013 25/10');
      expect(data.weekOffset, -1);
    });
  });

  group('2. Kiểm định Dải 7 ngày đếm số môn & Viên thuốc accent ngày hôm nay', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
    final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

    test('Dải 7 ngày chứa đúng 7 phần tử T2, T3, T4, T5, T6, T7, CN', () {
      expect(data.daysStrip.length, 7);
      expect(data.daysStrip.map((d) => d.weekdayLabel).toList(), [
        'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN',
      ]);
    });

    test('Mốc kiểm thử 28/10/2026: Dải số môn đạt chuẩn Spec Mục 5.2.4 (3 · 1 · 4 · 2 · 1 · · · ·)', () {
      final counts = data.daysStrip.map((d) => d.countText).toList();
      expect(counts, ['3', '1', '4', '2', '1', '\u00B7', '\u00B7']);

      // Chuỗi hiển thị phân tách dấu chấm: 3 · 1 · 4 · 2 · 1 · · · ·
      final joinedCounts = counts.join(' \u00B7 ');
      expect(joinedCounts, '3 \u00B7 1 \u00B7 4 \u00B7 2 \u00B7 1 \u00B7 \u00B7 \u00B7 \u00B7');
    });

    test('Hôm nay (T4 28/10) được đánh dấu isToday = true, các ngày khác isToday = false', () {
      for (int i = 0; i < 7; i++) {
        final day = data.daysStrip[i];
        if (i == 2) {
          // Index 2 là T4 (28/10)
          expect(day.isToday, isTrue);
          expect(day.sessionCount, 4);
        } else {
          expect(day.isToday, isFalse);
        }
      }
    });

    test('Ngày T7 và CN có 0 môn hiển thị dấu "·" mờ', () {
      expect(data.daysStrip[5].sessionCount, 0);
      expect(data.daysStrip[5].countText, '\u00B7');
      expect(data.daysStrip[6].sessionCount, 0);
      expect(data.daysStrip[6].countText, '\u00B7');
    });
  });

  group('3. Kiểm định Danh sách chi tiết, Vạch màu, Tiền tố "Thi ", Môn đã qua mờ xám', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
    final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

    test('Chỉ tạo nhóm ngày cho các ngày có lịch học (T2, T3, T4, T5, T6)', () {
      expect(data.dayGroups.length, 5);
      expect(data.dayGroups[0].headerTitle, 'T2 26/10');
      expect(data.dayGroups[1].headerTitle, 'T3 27/10');
      expect(data.dayGroups[2].headerTitle, 'Hôm nay \u00B7 T4 28/10');
      expect(data.dayGroups[3].headerTitle, 'T5 29/10');
      expect(data.dayGroups[4].headerTitle, 'T6 30/10');
    });

    test('Môn thi có isExam = true, tiền tố "Thi " và phòng căn phải', () {
      final t4Group = data.dayGroups[2];
      final examItem = t4Group.sessions.firstWhere((s) => s.isExam);

      expect(examItem.isExam, isTrue);
      expect(examItem.displayTitle.startsWith('Thi '), isTrue);
      expect(examItem.displayTitle, contains('Phương pháp luận'));
      expect(examItem.subjectTitle, 'Phương pháp luận nghiên cứu khoa học');
      expect(examItem.roomStr, 'B205');
      expect(examItem.timeStr, '09:45');
    });

    test('Môn đã qua của hôm nay (Lập trình Web 06:55–09:20) có isPast = true', () {
      final t4Group = data.dayGroups[2];
      final pastItem = t4Group.sessions.firstWhere((s) => s.session.id == 101);

      expect(pastItem.isPast, isTrue);
      expect(pastItem.isToday, isTrue);
      expect(pastItem.timeStr, '06:55');
      expect(pastItem.subjectTitle, 'Lập trình Web');
    });

    test('Các môn sắp tới trong hôm nay có isPast = false', () {
      final t4Group = data.dayGroups[2];
      final ctdlItem = t4Group.sessions.firstWhere((s) => s.session.id == 103);
      final netItem = t4Group.sessions.firstWhere((s) => s.session.id == 104);

      expect(ctdlItem.isPast, isFalse);
      expect(netItem.isPast, isFalse);
    });

    test('Phòng học được rút gọn chuẩn (B205 (SBD 0123) -> B205, P.101 -> P101)', () {
      expect(WidgetWeeklySelector.simplifyRoom('B205 (SBD 0123)'), 'B205');
      expect(WidgetWeeklySelector.simplifyRoom('P.101'), 'P101');
      expect(WidgetWeeklySelector.simplifyRoom('Lab3'), 'Lab3');
      expect(WidgetWeeklySelector.simplifyRoom('Sân A'), 'Sân A');
    });
  });

  group('4. Kiểm định Gộp các ngày trống liên tiếp (Ví dụ: "T7 – CN: không có lịch")', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('T7 và CN trống được gộp thành đúng dòng "T7 – CN: không có lịch"', () {
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

      expect(data.emptyDaysList.length, 1);
      final empty = data.emptyDaysList.first;
      expect(empty.startIndex, 5);
      expect(empty.endIndex, 6);
      expect(empty.startWeekday, 'T7');
      expect(empty.endWeekday, 'CN');
      expect(empty.displayTitle, 'T7 \u2013 CN: không có lịch');
    });

    test('Tuần chỉ học T4: gộp T2-T3 thành "T2 – T3: không có lịch" và T5-CN thành "T5 – CN: không có lịch"', () {
      final singleDaySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionWeb, sessionExamPpl],
      );

      final data = WidgetWeeklySelector.select(snapshot: singleDaySnapshot, now: now1005);
      expect(data.emptyDaysList.length, 2);
      expect(data.emptyDaysList[0].displayTitle, 'T2 \u2013 T3: không có lịch');
      expect(data.emptyDaysList[1].displayTitle, 'T5 \u2013 CN: không có lịch');
    });

    test('Ngày trống đơn lẻ ở giữa tuần hiển thị "Thứ: không có lịch"', () {
      final customSnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [sessionT2_1, sessionWeb], // Chỉ học T2 và T4, T3 trống đơn lẻ
      );

      final data = WidgetWeeklySelector.select(snapshot: customSnapshot, now: now1005);
      final t3Empty = data.emptyDaysList.firstWhere((e) => e.startIndex == 1);
      expect(t3Empty.displayTitle, 'T3: không có lịch');
    });

    test('Tuần hoàn toàn trống: hiển thị "T2 – CN: không có lịch"', () {
      final emptySnapshot = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: const [],
      );

      final data = WidgetWeeklySelector.select(snapshot: emptySnapshot, now: now1005);
      expect(data.emptyDaysList.length, 1);
      expect(data.emptyDaysList.first.displayTitle, 'T2 \u2013 CN: không có lịch');
    });
  });

  group('5. Kiểm định AC-11: Bảo toàn hiển thị lịch thi chưa diễn ra khi tràn chỗ', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('Khi giới hạn số hàng (maxSessions = 3), ca thi PPL NCKH chưa diễn ra tuyệt đối không bị cắt', () {
      // Tuần có tổng cộng 11 ca học/thi
      expect(fullSnapshot.sessions.length, 11);

      // Thu hẹp xuống tối đa 3 sessions
      final limitedData = WidgetWeeklySelector.selectWithLimit(
        snapshot: fullSnapshot,
        now: now1005,
        maxSessions: 3,
      );

      // Kiểm tra ca thi PPL NCKH có mặt trong danh sách được chọn
      final allVisibleSessions = <WeeklySessionItem>[];
      for (final g in limitedData.dayGroups) {
        allVisibleSessions.addAll(g.sessions);
      }

      final hasExam = allVisibleSessions.any((s) => s.session.id == 102 && s.isExam);
      expect(hasExam, isTrue, reason: 'AC-11: Ca thi chưa diễn ra phải luôn được bảo toàn hiển thị!');

      // Số môn bị ẩn được đếm chính xác
      expect(limitedData.hiddenCount, 11 - allVisibleSessions.length);
      expect(limitedData.footerText, '+${limitedData.hiddenCount} môn nữa');
    });

    test('Tuần có 2 ca thi chưa diễn ra, khi maxSessions = 2 thì cả 2 ca thi đều được ưu tiên giữ lại', () {
      final futureExam = Session(
        id: 999,
        kind: SessionKind.examSession,
        subjectName: 'Thi Tiếng Anh chuyên ngành',
        shortName: 'Thi TA',
        start: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 30, 8, 0),
        end: WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, 30, 10, 0),
        room: 'B101',
        colorIndex: 4,
      );

      final snapshotWith2Exams = WidgetScheduleSnapshot(
        version: 1,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: [...fullSnapshot.sessions, futureExam],
      );

      final limitedData = WidgetWeeklySelector.selectWithLimit(
        snapshot: snapshotWith2Exams,
        now: now1005,
        maxSessions: 2,
      );

      final allVisible = <WeeklySessionItem>[];
      for (final g in limitedData.dayGroups) {
        allVisible.addAll(g.sessions);
      }

      expect(allVisible.length, 2);
      expect(allVisible.any((s) => s.session.id == 102), isTrue);
      expect(allVisible.any((s) => s.session.id == 999), isTrue);
    });
  });

  group('6. Kiểm định AC-10: Trạng thái trống "Đăng nhập để xem lịch"', () {
    final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);

    test('snapshot = null -> hasSnapshot = false, authMessage = "Đăng nhập để xem lịch"', () {
      final data = WidgetWeeklySelector.select(snapshot: null, now: now1005);
      expect(data.hasSnapshot, isFalse);
      expect(data.authMessage, 'Đăng nhập để xem lịch');
      expect(data.dayGroups.isEmpty, isTrue);
      expect(data.daysStrip.length, 7);
      expect(data.daysStrip.every((d) => d.countText == '\u00B7'), isTrue);
    });

    test('snapshot.version != 1 -> fallback an toàn, không crash, authMessage = "Đăng nhập để xem lịch"', () {
      final invalidSnapshot = WidgetScheduleSnapshot(
        version: 999, // Version không hỗ trợ
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        sessions: const [],
      );

      final data = WidgetWeeklySelector.select(snapshot: invalidSnapshot, now: now1005);
      expect(data.hasSnapshot, isFalse);
      expect(data.authMessage, 'Đăng nhập để xem lịch');
    });
  });

  group('7. Kiểm định AC-08: Zero Hardcoded Time Strings trong toàn bộ mã nguồn Bước 5', () {
    test('Không có mốc giờ cố định \\b\\d{1,2}:\\d{2}\\b trong toàn bộ file của Widget Tuần 4x4', () {
      final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

      final filesToCheck = [
        'android/app/src/main/kotlin/com/tramkien/hau/WeeklyScheduleWidgetProvider.kt',
        'android/app/src/main/res/layout/widget_schedule_weekly.xml',
        'android/app/src/main/res/layout/widget_weekly_item_header.xml',
        'android/app/src/main/res/layout/widget_weekly_item_session.xml',
        'android/app/src/main/res/layout/widget_weekly_item_empty.xml',
        'android/app/src/main/res/xml/widget_schedule_weekly_info.xml',
        'ios/Runner/ScheduleWidgetKit.swift',
        'lib/services/widget/widget_weekly_selector.dart',
        'lib/widgets/widget_weekly_4x4_card.dart',
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

  group('8. Widget Test: Render Widget Tuần 4x4 (Flutter Parity Card)', () {
    testWidgets('Render chuẩn mốc Spec 28/10/2026 10:05: Dải 7 ngày, ca thi đỏ, môn đã qua mờ xám, dòng gộp', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetWeekly4x4Card(data: data),
            ),
          ),
        ),
      );

      // 1. Kiểm tra tiêu đề tuần
      expect(find.text('Tuần 26/10 \u2013 01/11'), findsOneWidget);

      // 2. Kiểm tra các nhãn thứ trong dải 7 ngày
      expect(find.text('T2'), findsWidgets);
      expect(find.text('T3'), findsWidgets);
      expect(find.text('T4'), findsWidgets);
      expect(find.text('T5'), findsWidgets);
      expect(find.text('T6'), findsWidgets);
      expect(find.text('T7'), findsWidgets);
      expect(find.text('CN'), findsWidgets);

      // 3. Kiểm tra số môn trong dải 7 ngày: T2(3), T3(1), T4(4), T5(2), T6(1), T7 và CN (·)
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('\u00B7'), findsWidgets); // T7 và CN

      // 4. Kiểm tra tiêu đề nhóm ngày
      expect(find.text('Hôm nay \u00B7 T4 28/10'), findsOneWidget);

      // 5. Kiểm tra ca thi có tiền tố "Thi "
      expect(find.textContaining('Thi Phương pháp luận'), findsOneWidget);

      // 6. Kiểm tra dòng gộp ngày trống liên tiếp
      expect(find.text('T7 \u2013 CN: không có lịch'), findsOneWidget);
    });

    testWidgets('Render trạng thái chưa có snapshot hiển thị "Đăng nhập để xem lịch"', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final emptyData = WidgetWeeklySelector.select(snapshot: null, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetWeekly4x4Card(data: emptyData),
            ),
          ),
        ),
      );

      expect(find.text('Đăng nhập để xem lịch'), findsOneWidget);
    });

    testWidgets('Kiểm tra nút bấm ‹ và › chuyển tuần kích hoạt callback', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

      bool prevClicked = false;
      bool nextClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetWeekly4x4Card(
                data: data,
                onPrevWeek: () => prevClicked = true,
                onNextWeek: () => nextClicked = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('‹'));
      expect(prevClicked, isTrue);

      await tester.tap(find.text('›'));
      expect(nextClicked, isTrue);
    });

    testWidgets('Render Dark Mode không ném ngoại lệ và bảo toàn token', (tester) async {
      final now1005 = WidgetTimeUtils.vnComponentsToDateTime(testYear, testMonth, testDay, 10, 5);
      final data = WidgetWeeklySelector.select(snapshot: fullSnapshot, now: now1005);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: WidgetWeekly4x4Card(data: data, isDarkMode: true),
            ),
          ),
        ),
      );

      expect(find.text('Tuần 26/10 \u2013 01/11'), findsOneWidget);
      expect(find.text('T7 \u2013 CN: không có lịch'), findsOneWidget);
    });
  });
}
