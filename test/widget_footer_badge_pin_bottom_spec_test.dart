import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testConfig = WidgetThemeConfig(
    layoutMode: 'single_day',
    bgStyle: 'solid',
    bgColorHex: '#1C1C1E',
    bgOpacity: 1.0,
    textPrimaryHex: '#FFFFFF',
    textSecondaryHex: '#98989D',
    accentColorHex: '#1D64F2',
    showRoom: true,
    showTime: true,
    showTeacher: true,
    showClassCode: true,
  );

  group('SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Ghim (+N môn nữa) sát đáy Footer trong Live Preview Studio
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Pinned Footer Badge in WidgetStudioScreen Live Preview', () {
      test('lib/screens/widget_studio_screen.dart source contains Spacer() before (+N môn nữa)', () {
        final studioFile = File('lib/screens/widget_studio_screen.dart');
        expect(studioFile.existsSync(), isTrue);
        final content = studioFile.readAsStringSync();

        final methodIdx = content.indexOf('_buildSingleDay4x2TimelineContent(');
        expect(methodIdx != -1, isTrue, reason: '_buildSingleDay4x2TimelineContent must exist');
        final methodBlock = content.substring(methodIdx, methodIdx + 1600);

        // Check Spacer() is used instead of SizedBox(height: 5)
        expect(methodBlock.contains('const Spacer()'), isTrue,
            reason: 'Must contain const Spacer() to pin (+N môn nữa) to bottom footer');
        expect(methodBlock.contains("'(+\${classes.length - 2} môn nữa)'"), isTrue);
      });

      testWidgets('Live preview renders Spacer and footer badge (+2 môn nữa) at bottom for 4 courses', (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));

        final mockData = WidgetScheduleData(
          updatedAt: '2026-10-27T08:00:00Z',
          layoutMode: 'single_day',
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Ba, 27/10',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'Hôm nay',
              dateStr: '27/10',
              weekdayStr: 'Thứ Ba',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Môn 1: Kiến trúc máy tính',
                  room: 'P.101',
                  timeSlot: '07:00 – 09:20',
                  teacher: 'ThS. Nguyễn Văn A',
                  classCode: 'KTMT01',
                  isExam: false,
                ),
                WidgetClassItem(
                  courseName: 'Môn 2: Mạng máy tính',
                  room: 'P.102',
                  timeSlot: '09:30 – 11:50',
                  teacher: 'TS. Trần Văn B',
                  classCode: 'MMT02',
                  isExam: false,
                ),
                WidgetClassItem(
                  courseName: 'Môn 3: Cơ sở dữ liệu',
                  room: 'P.201',
                  timeSlot: '12:45 – 15:10',
                  teacher: 'ThS. Lê Văn C',
                  classCode: 'CSDL03',
                  isExam: false,
                ),
                WidgetClassItem(
                  courseName: 'Môn 4: Trí tuệ nhân tạo',
                  room: 'P.202',
                  timeSlot: '15:20 – 17:45',
                  teacher: 'PGS. Hoàng Văn D',
                  classCode: 'TTNT04',
                  isExam: false,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: testConfig,
              previewScheduleData: mockData,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra thấy 2 môn đầu và badge (+2 môn nữa)
        expect(find.text('Môn 1: Kiến trúc máy tính'), findsOneWidget);
        expect(find.text('Môn 2: Mạng máy tính'), findsOneWidget);
        final badgeFinder = find.text('(+2 môn nữa)');
        expect(badgeFinder, findsOneWidget);

        // Spacer exists in widget tree
        expect(find.byType(Spacer), findsWidgets);

        // Toạ độ Y của badge (+2 môn nữa) phải nằm thấp hơn toạ độ của Môn 2
        final course2Pos = tester.getBottomLeft(find.text('Môn 2: Mạng máy tính'));
        final badgePos = tester.getTopLeft(badgeFinder);
        // Có Spacer đẩy nên khoảng cách giữa đáy Môn 2 và đỉnh Badge phải lớn hơn 8dp thông thường
        expect(badgePos.dy - course2Pos.dy, greaterThan(15.0));
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Ghim single_day_badge sát đáy Footer trên Android Native (4x2)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Android Native XML & ScheduleWidgetProvider Parity', () {
      test('widget_schedule_single_day.xml defines single_day_spacer with weight=1 before badge', () {
        final xmlFile = File('android/app/src/main/res/layout/widget_schedule_single_day.xml');
        expect(xmlFile.existsSync(), isTrue);
        final xml = xmlFile.readAsStringSync();

        // 1. Must define single_day_spacer as ImageView with layout_weight="1" and layout_height="0dp"
        expect(xml.contains('android:id="@+id/single_day_spacer"'), isTrue,
            reason: 'widget_schedule_single_day.xml must declare @+id/single_day_spacer');
        expect(
          xml.contains('android:layout_height="0dp"') && xml.contains('android:layout_weight="1"'),
          isTrue,
        );

        // 2. single_day_spacer must precede single_day_badge
        final spacerIdx = xml.indexOf('android:id="@+id/single_day_spacer"');
        final badgeIdx = xml.indexOf('android:id="@+id/single_day_badge"');
        expect(spacerIdx != -1 && badgeIdx != -1, isTrue);
        expect(spacerIdx < badgeIdx, isTrue,
            reason: 'single_day_spacer must be placed before single_day_badge in layout flow');

        // 3. RemoteViews compatibility: zero bare <View> tags
        expect(
          RegExp(r'<View[\s/>]').hasMatch(xml),
          isFalse,
          reason: 'Must not use bare <View> tags in widget layout',
        );
      });

      test('ScheduleWidgetProvider.kt controls single_day_spacer visibility based on class count', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        // In single_day section:
        expect(kt.contains('R.id.single_day_spacer'), isTrue,
            reason: 'ScheduleWidgetProvider.kt must reference R.id.single_day_spacer');

        // When displayClasses.size > 2, spacer is VISIBLE
        expect(
          kt.contains('views.setViewVisibility(R.id.single_day_spacer, View.VISIBLE)'),
          isTrue,
          reason: 'single_day_spacer must be set to View.VISIBLE when displayClasses.size > 2',
        );

        // When displayClasses.size <= 2, spacer is GONE
        expect(
          kt.contains('views.setViewVisibility(R.id.single_day_spacer, View.GONE)'),
          isTrue,
          reason: 'single_day_spacer must be set to View.GONE when displayClasses.size <= 2',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Đồng bộ ghim Footer (+N môn nữa) trên iOS WidgetKit
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: iOS WidgetKit .systemMedium Timeline Parity', () {
      test('ScheduleWidgetKit.swift places Spacer(minLength: 0) before (+N môn nữa) in .systemMedium', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        final systemMediumIdx = swift.indexOf('// systemMedium (4x2 Timeline Minimalist Layout)');
        expect(systemMediumIdx != -1, isTrue);
        final systemMediumEndIdx = swift.indexOf('private var backgroundView:', systemMediumIdx);
        final systemMediumBlock = swift.substring(systemMediumIdx, systemMediumEndIdx != -1 ? systemMediumEndIdx : swift.length);

        // Verify Spacer(minLength: 0) precedes the badge block
        final spacerIdx = systemMediumBlock.lastIndexOf('Spacer(minLength: 0)');
        final badgeIdx = systemMediumBlock.indexOf('if displayClasses.count > 2');
        expect(spacerIdx != -1 && badgeIdx != -1, isTrue);
        expect(spacerIdx < badgeIdx, isTrue,
            reason: 'In .systemMedium, Spacer(minLength: 0) must precede if displayClasses.count > 2');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Bảo toàn hiển thị khi có 1 hoặc 2 môn học
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Clean Top-Aligned Layout when <= 2 courses', () {
      testWidgets('Live preview renders cleanly without overflow or badge when 1 course', (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));

        final oneCourseData = WidgetScheduleData(
          updatedAt: '2026-10-27T08:00:00Z',
          layoutMode: 'single_day',
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Ba, 27/10',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'Hôm nay',
              dateStr: '27/10',
              weekdayStr: 'Thứ Ba',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Toán rời rạc ứng dụng',
                  room: 'P.301',
                  timeSlot: '07:00 – 09:20',
                  teacher: 'TS. Nguyễn Văn E',
                  classCode: 'TR01',
                  isExam: false,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: testConfig,
              previewScheduleData: oneCourseData,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Toán rời rạc ứng dụng'), findsOneWidget);
        expect(find.textContaining('môn nữa'), findsNothing);
      });

      testWidgets('Live preview renders cleanly without overflow or badge when exactly 2 courses', (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));

        final twoCoursesData = WidgetScheduleData(
          updatedAt: '2026-10-27T08:00:00Z',
          layoutMode: 'single_day',
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Ba, 27/10',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'Hôm nay',
              dateStr: '27/10',
              weekdayStr: 'Thứ Ba',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Toán rời rạc',
                  room: 'P.301',
                  timeSlot: '07:00 – 09:20',
                  teacher: 'TS. Nguyễn Văn E',
                  classCode: 'TR01',
                  isExam: false,
                ),
                WidgetClassItem(
                  courseName: 'Lập trình Flutter nâng cao',
                  room: 'P.302',
                  timeSlot: '09:30 – 11:50',
                  teacher: 'ThS. Lê Văn F',
                  classCode: 'FL02',
                  isExam: false,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: testConfig,
              previewScheduleData: twoCoursesData,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Toán rời rạc'), findsOneWidget);
        expect(find.text('Lập trình Flutter nâng cao'), findsOneWidget);
        expect(find.textContaining('môn nữa'), findsNothing);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn Test Suite & Không gây Regression Bug
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Parity & Integrity Preservation across All 3 Platforms', () {
      test('All target files exist and maintain structure integrity', () {
        expect(File('lib/screens/widget_studio_screen.dart').existsSync(), isTrue);
        expect(File('android/app/src/main/res/layout/widget_schedule_single_day.xml').existsSync(), isTrue);
        expect(File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt').existsSync(), isTrue);
        expect(File('ios/Runner/ScheduleWidgetKit.swift').existsSync(), isTrue);
      });
    });
  });
}
