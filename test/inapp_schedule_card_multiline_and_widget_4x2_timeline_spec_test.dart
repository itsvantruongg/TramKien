import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-SCHEDULE-CARD-MULTILINE-WIDGET-4X2-TIMELINE-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Tự động xuống dòng đa dòng (Wrap) trên thẻ In-App (iOS & Android)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Responsive Multi-line Wrap in ScheduleCard & _ScheduleCardFull', () {
      test('lib/widgets/shared_widgets.dart ScheduleCard uses Wrap with spacing: 8, runSpacing: 6', () {
        final sharedFile = File('lib/widgets/shared_widgets.dart');
        expect(sharedFile.existsSync(), isTrue);
        final content = sharedFile.readAsStringSync();

        final scheduleCardBlock = content.substring(
          content.indexOf('class ScheduleCard extends StatelessWidget'),
          content.indexOf('typedef ScheduleTimelineCard = ScheduleCard;'),
        );

        expect(scheduleCardBlock.contains('Wrap('), isTrue);
        expect(scheduleCardBlock.contains('spacing: 8'), isTrue);
        expect(scheduleCardBlock.contains('runSpacing: 6'), isTrue);
        expect(scheduleCardBlock.contains('crossAxisAlignment: WrapCrossAlignment.center'), isTrue);
        expect(
          scheduleCardBlock.contains('SingleChildScrollView(') &&
          scheduleCardBlock.contains('NeverScrollableScrollPhysics()'),
          isFalse,
          reason: 'ScheduleCard must eliminate horizontal SingleChildScrollView to avoid clipping',
        );
      });

      test('lib/screens/schedule_screen.dart _ScheduleCardFull uses Wrap with spacing: 8, runSpacing: 6', () {
        final screenFile = File('lib/screens/schedule_screen.dart');
        expect(screenFile.existsSync(), isTrue);
        final content = screenFile.readAsStringSync();

        final cardFullIdx = content.indexOf('class _ScheduleCardFull extends StatelessWidget');
        expect(cardFullIdx != -1, isTrue);
        final cardFullBlock = content.substring(cardFullIdx, cardFullIdx + 1600);

        expect(cardFullBlock.contains('Wrap('), isTrue);
        expect(cardFullBlock.contains('spacing: 8'), isTrue);
        expect(cardFullBlock.contains('runSpacing: 6'), isTrue);
        expect(cardFullBlock.contains('crossAxisAlignment: WrapCrossAlignment.center'), isTrue);
        expect(
          cardFullBlock.contains('SingleChildScrollView(') &&
          cardFullBlock.contains('NeverScrollableScrollPhysics()'),
          isFalse,
          reason: '_ScheduleCardFull must eliminate horizontal SingleChildScrollView to avoid clipping',
        );
      });

      testWidgets('ScheduleCard renders Wrap chips cleanly on realistic container without silent clipping', (tester) async {
        const dummy = LichHoc(
          tenHocPhan: 'Kiến trúc phần mềm và hệ phân tán',
          soTinChi: 3,
          tenLopTinChi: 'TH4327_23CN 2',
          thoiGian: '12:45 – 17:00',
          thu: 'Thứ 2',
          tiet: '8-12',
          phong: 'P.M-M5.03',
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
        await tester.pumpAndSettle();

        expect(find.byType(Wrap), findsOneWidget);
        expect(find.text(dummy.phong), findsOneWidget);
        expect(find.text('Tiết ${dummy.tiet}'), findsOneWidget);
        expect(find.text(dummy.giaoVien), findsOneWidget);
        expect(find.text(dummy.tenLopTinChi), findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Phân định Nhãn Android Launcher
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Distinct Android Launcher Widget Labels in AndroidManifest.xml', () {
      test('AndroidManifest.xml distinguishes 4x2 Timeline and 2x2 Thu gọn labels', () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(manifestFile.existsSync(), isTrue);
        final manifest = manifestFile.readAsStringSync();

        expect(
          manifest.contains('.SingleDayScheduleWidgetProvider') &&
          manifest.contains('android:label="Lịch hôm nay (4x2 Timeline)"'),
          isTrue,
          reason: 'SingleDayScheduleWidgetProvider must have label="Lịch hôm nay (4x2 Timeline)"',
        );

        // SPEC-WIDGET-CLEANUP-2X2: Receiver 2x2 đã được gỡ bỏ khỏi AndroidManifest.xml
        expect(
          manifest.contains('.SingleDay2x2ScheduleWidgetProvider'),
          isFalse,
          reason: 'SingleDay2x2ScheduleWidgetProvider must be removed per SPEC-WIDGET-CLEANUP-2X2',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Bố cục Timeline trực quan & Triệt tiêu khoảng trống trên Android Widget 4x2
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Android 4x2 Visual Timeline Layout & Vertical Balance', () {
      test('widget_schedule_single_day.xml has center_vertical gravity and timeline indicator views', () {
        final layoutFile = File('android/app/src/main/res/layout/widget_schedule_single_day.xml');
        expect(layoutFile.existsSync(), isTrue);
        final xml = layoutFile.readAsStringSync();

        // RemoteViews safety check
        expect(
          RegExp(r'<View[\s/>]').hasMatch(xml),
          isFalse,
          reason: 'Must not contain bare <View> tags to prevent InflateException in RemoteViews',
        );

        // Top alignment (SPEC-WIDGET-CLEANUP-2X2)
        expect(
          xml.contains('android:id="@+id/single_day_content"') &&
          xml.contains('android:gravity="top"'),
          isTrue,
          reason: 'single_day_content must use gravity="top" per SPEC-WIDGET-CLEANUP-2X2',
        );

        // Timeline indicators
        expect(xml.contains('android:id="@+id/single_class_1_indicator"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_indicator"'), isTrue);

        // Course details
        expect(xml.contains('android:id="@+id/single_class_1_time"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_1_name"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_1_hybrid"'), isTrue);
      });

      test('ScheduleWidgetProvider.kt sets accent and exam colors on timeline indicators', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        expect(kt.contains('R.id.single_class_1_indicator'), isTrue);
        expect(kt.contains('R.id.single_class_2_indicator'), isTrue);
        expect(kt.contains('views.setInt(R.id.single_class_1_indicator, "setBackgroundColor"'), isTrue);
        expect(kt.contains('views.setInt(R.id.single_class_2_indicator, "setBackgroundColor"'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Nâng cấp đồng bộ iOS WidgetKit (.systemMedium)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: iOS WidgetKit .systemMedium Timeline Parity', () {
      test('ScheduleWidgetKit.swift provides Capsule indicator and vertical centering for single course', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        // Check .systemMedium branch has Capsule indicator and top alignment
        expect(swift.contains('// systemMedium (4x2 Timeline Minimalist Layout)'), isTrue);
        expect(swift.contains('Capsule()'), isTrue);
        expect(swift.contains('.fill(c.isExam == true ? Color.red : (Color(hex: entry.accentColorHex) ?? .blue))'), isTrue);
        // SPEC-WIDGET-CLEANUP-2X2: Top-aligned, eliminated Spacer() above single course
        expect(swift.contains('if displayClasses.count == 1'), isFalse);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Đồng bộ Live Preview 4x2 trong Widget Studio
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Live Preview 4x2 Timeline in Widget Studio', () {
      testWidgets('WidgetStudioScreen defaults to 4x2 Timeline and removes 2x2 toggle', (tester) async {
        final sampleData = WidgetScheduleData(
          updatedAt: '2026-10-26T07:00:00Z',
          layoutMode: 'single_day',
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Hai, 26/10',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'Hôm nay',
              dateStr: '26/10',
              weekdayStr: 'Thứ Hai',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Đồ họa và hiện thực ảo',
                  room: 'P.M-M5.03',
                  timeSlot: '06:55 – 09:20',
                  teacher: 'ThS. Nguyễn Văn A',
                  classCode: 'TH4327_23CN 2',
                  isExam: false,
                ),
                WidgetClassItem(
                  courseName: 'Hệ trợ giúp quyết định',
                  room: 'P.M-M5.02',
                  timeSlot: '12:45 – 17:00',
                  teacher: 'TS. Trần Văn B',
                  classCode: 'TH4328_23CN 2',
                  isExam: false,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: const WidgetThemeConfig(
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
              ),
              previewScheduleData: sampleData,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // SPEC-WIDGET-CLEANUP-2X2: 2x2 button removed, single_day defaults directly to 4x2 Timeline
        expect(find.byKey(const Key('variant_single_day_2x2')), findsNothing);

        // 4x2 Timeline elements rendered directly in live preview
        expect(find.text('7h'), findsWidgets);
        expect(find.text('12h45'), findsWidgets);
        expect(find.text('Đồ họa và hiện thực ảo'), findsWidgets);
      });
    });
  });
}
