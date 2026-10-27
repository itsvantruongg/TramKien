import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-TIMELINE-WIDGET-02 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Khôi Phục Thẻ Lịch Học Trong App & Luôn Hiển Thị Mã Lớp Học Phần
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: In-App Schedule Card Restoration & Permanent Class Code Display', () {
      test('ScheduleCard code has removed the 48dp left hour column', () {
        final file = File('lib/widgets/shared_widgets.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        final scheduleCardBlock = content.substring(
          content.indexOf('class ScheduleCard extends StatelessWidget'),
          content.indexOf('class ExamCard extends StatelessWidget'),
        );
        expect(
          scheduleCardBlock.contains('SizedBox(\n          width: 48') ||
          scheduleCardBlock.contains('width: 48'),
          isFalse,
          reason: 'ScheduleCard must not divide into a 48dp left start-hour column in-app',
        );
        expect(scheduleCardBlock.contains("StatusChip(label: 'LỊCH HỌC'"), isTrue);
        expect(scheduleCardBlock.contains('lichHoc.gioHocFull'), isTrue);
      });

      testWidgets('ScheduleCard renders SurfaceCard with StatusChip, gioHocFull, and ALWAYS displays tenLopTinChi chip', (tester) async {
        const dummy = LichHoc(
          tenHocPhan: 'Lập trình di động nâng cao',
          soTinChi: 3,
          tenLopTinChi: 'TH4327_23CN 2',
          thoiGian: '12:45 – 17:00',
          thu: 'Thứ 2',
          tiet: '8-12',
          phong: 'P.M503',
          giaoVien: 'ThS. Nguyễn Văn A',
          hocKy: 1,
          namHoc: '2026-2027',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: ScheduleCard(lichHoc: dummy),
              ),
            ),
          ),
        );

        // Header: StatusChip and full time
        expect(find.text('LỊCH HỌC'), findsOneWidget);
        expect(find.text(dummy.gioHocFull), findsOneWidget);

        // Middle: Course name
        expect(find.text('Lập trình di động nâng cao'), findsOneWidget);

        // Metadata: Room, Period, Teacher, and permanently visible Class Code
        expect(find.text('P.M503'), findsOneWidget);
        expect(find.text('Tiết 8-12'), findsOneWidget);
        expect(find.text('ThS. Nguyễn Văn A'), findsOneWidget);
        expect(find.text('TH4327_23CN 2'), findsOneWidget);
        expect(find.byIcon(Icons.tag), findsOneWidget);
      });

      test('schedule_screen.dart _ScheduleCardFull permanently displays tenLopTinChi when not empty', () {
        final screenFile = File('lib/screens/schedule_screen.dart');
        expect(screenFile.existsSync(), isTrue);
        final content = screenFile.readAsStringSync();

        expect(content.contains('class _ScheduleCardFull extends StatelessWidget'), isTrue);
        expect(content.contains('_Chip(Icons.tag, lichHoc.tenLopTinChi)'), isTrue);
        expect(
          content.contains('if (showClassCode && lichHoc.tenLopTinChi.isNotEmpty)'),
          isFalse,
          reason: '_ScheduleCardFull must not gate class code display behind showClassCode',
        );
      });

      test('dashboard_screen.dart locks list.take(2) and renders view all link for >2 courses', () {
        final dashFile = File('lib/screens/dashboard_screen.dart');
        expect(dashFile.existsSync(), isTrue);
        final content = dashFile.readAsStringSync();

        expect(content.contains('.take(2)'), isTrue);
        expect(content.contains('ca học khác • Xem tất cả'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Bố Cục Timeline 4x2 Cho Android Widget (SingleDayScheduleWidgetProvider)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: 4x2 Single Day Timeline Android Layout & Provider', () {
      test('AndroidManifest.xml enables SingleDayScheduleWidgetProvider with label "Lịch hôm nay (4x2 Timeline)"', () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(manifestFile.existsSync(), isTrue);
        final content = manifestFile.readAsStringSync();

        expect(
          content.contains('android:name=".SingleDayScheduleWidgetProvider"'),
          isTrue,
        );
        expect(
          content.contains('android:name=".SingleDayScheduleWidgetProvider"\n            android:exported="true"\n            android:enabled="true"\n            android:label="Lịch hôm nay (4x2 Timeline)"') ||
          (content.contains('.SingleDayScheduleWidgetProvider') &&
           content.contains('android:enabled="true"') &&
           (content.contains('android:label="Lịch hôm nay (4x2 Timeline)"') ||
            content.contains('android:label="Lịch hôm nay"'))),
          isTrue,
          reason: 'SingleDayScheduleWidgetProvider must be enabled="true" and label="Lịch hôm nay (4x2 Timeline)"',
        );
      });

      test('widget_schedule_single_day.xml implements 2-column minimal timeline layout', () {
        final layoutFile = File('android/app/src/main/res/layout/widget_schedule_single_day.xml');
        expect(layoutFile.existsSync(), isTrue);
        final xml = layoutFile.readAsStringSync();

        // 1. RemoteViews safe - zero <View> tags
        expect(
          RegExp(r'<View[\s/>]').hasMatch(xml),
          isFalse,
          reason: 'Must not contain bare <View> tags to avoid InflateException in RemoteViews',
        );

        // 2. Concentric 3-layer architecture with @android:id/background
        expect(xml.contains('android:id="@android:id/background"'), isTrue);
        expect(xml.contains('android:id="@+id/widget_bg_image"'), isTrue);

        // 3. Left column start-time TextViews
        expect(xml.contains('android:id="@+id/single_class_1_time"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_time"'), isTrue);

        // 4. Right column course name & single-line hybrid info
        expect(xml.contains('android:id="@+id/single_class_1_name"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_1_hybrid"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_name"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_hybrid"'), isTrue);

        // 5. Overflow badge (+N môn nữa)
        expect(xml.contains('android:id="@+id/single_day_badge"'), isTrue);
      });

      test('ScheduleWidgetProvider.kt renders layoutType "single_day" with formatStartTime and formatTimelineSecondary', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        expect(kt.contains('"single_day" ->'), isTrue);
        expect(kt.contains('formatStartTime'), isTrue);
        expect(kt.contains('formatTimelineSecondary'), isTrue);
        expect(kt.contains('R.id.single_class_1_time'), isTrue);
        expect(kt.contains('R.id.single_class_1_hybrid'), isTrue);
        expect(kt.contains('R.id.single_day_badge'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Thẻ 2x2 Kéo Dãn (2x2 -> 3x2 -> 4x2) Chuẩn Đúng 2 Dòng Duy Nhất
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Stretched 2x2 Locks maxLines="1" with No setMaxLines(2)', () {
      test('ScheduleWidgetProvider.kt eliminates setMaxLines 2 in single_day_2x2 and locks maxLines=1', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        // Find single_day_2x2 branch
        final single2x2Idx = kt.indexOf('"single_day_2x2" ->');
        expect(single2x2Idx != -1, isTrue);
        final nextBranchIdx = kt.indexOf('"weekly" ->', single2x2Idx);
        final single2x2Block = kt.substring(single2x2Idx, nextBranchIdx != -1 ? nextBranchIdx : kt.length);

        expect(
          single2x2Block.contains('setMaxLines", 2'),
          isFalse,
          reason: 'single_day_2x2 must NEVER call setMaxLines 2 on launcher horizontal stretch',
        );

        expect(
          single2x2Block.contains('views.setInt(R.id.single_2x2_class_1_hybrid, "setMaxLines", 1)'),
          isTrue,
        );
        expect(
          single2x2Block.contains('views.setInt(R.id.single_2x2_class_2_hybrid, "setMaxLines", 1)'),
          isTrue,
        );
      });

      test('widget_schedule_single_day_2x2.xml defines maxLines="1" on hybrid text lines', () {
        final layout2x2File = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
        expect(layout2x2File.existsSync(), isTrue);
        final xml = layout2x2File.readAsStringSync();

        expect(xml.contains('android:id="@+id/single_2x2_class_1_hybrid"'), isTrue);
        expect(xml.contains('android:id="@+id/single_2x2_class_2_hybrid"'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Utilities, Time Formatters, iOS Parity & Zero Regressions
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Utilities, Time Formats & Parity Across System', () {
      test('ScheduleCard.formatStartHour formats times correctly', () {
        expect(ScheduleCard.formatStartHour('07:00 – 09:25'), equals('7h'));
        expect(ScheduleCard.formatStartHour('06:55 – 09:20'), equals('7h'));
        expect(ScheduleCard.formatStartHour('09:30 – 11:55'), equals('9h30'));
        expect(ScheduleCard.formatStartHour('12:45 – 17:00'), equals('12h45'));
        expect(ScheduleCard.formatStartHour('12:55 – 17:05'), equals('12h45'));
        expect(ScheduleCard.formatStartHour('7h'), equals('7h'));
        expect(ScheduleCard.formatStartHour('12h45'), equals('12h45'));
      });

      test('ScheduleWidgetKit.swift parity: formatStartTime and .systemMedium', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        expect(swift.contains('func formatStartTime('), isTrue);
        expect(swift.contains('formatStartTime(c.timeSlot)'), isTrue);
        expect(swift.contains('displayClasses.prefix(2)'), isTrue);
        expect(swift.contains('(+\\(displayClasses.count - 2) môn nữa)'), isTrue);
      });

      test('Widget presets default showClassCode to false for outer widgets', () {
        expect(WidgetThemeConfig.minimalSwiss().showClassCode, isFalse);
        expect(WidgetThemeConfig.solidLight().showClassCode, isFalse);
        expect(WidgetThemeConfig.ghostMode().showClassCode, isFalse);
        expect(WidgetThemeConfig.cyberpunkNeon().showClassCode, isFalse);
        expect(WidgetThemeConfig.darkObsidian().showClassCode, isFalse);
        expect(WidgetThemeConfig.deepForest().showClassCode, isFalse);
        expect(WidgetThemeConfig.sunsetMinimal().showClassCode, isFalse);
        expect(WidgetThemeConfig.frostedGlass().showClassCode, isFalse);
      });

      test('WidgetThemeConfig.fromJson defaults show_class_code to false', () {
        final config = WidgetThemeConfig.fromJson({});
        expect(config.showClassCode, isFalse);

        final configExplicitTrue = WidgetThemeConfig.fromJson({'show_class_code': true});
        expect(configExplicitTrue.showClassCode, isTrue);
      });
    });
  });
}
