import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Cột trái Widget 4x2 hiển thị đầy đủ Giờ bắt đầu & Giờ kết thúc (Android)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Android 4x2 Dual-Timestamp Timeline & 28dp Indicator', () {
      test('widget_schedule_single_day.xml defines start and end time TextViews and 28dp indicator', () {
        final xmlFile = File('android/app/src/main/res/layout/widget_schedule_single_day.xml');
        expect(xmlFile.existsSync(), isTrue);
        final xml = xmlFile.readAsStringSync();

        // Class 1
        expect(xml.contains('android:id="@+id/single_class_1_time"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_1_time_end"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_1_indicator"'), isTrue);

        // Class 2
        expect(xml.contains('android:id="@+id/single_class_2_time"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_time_end"'), isTrue);
        expect(xml.contains('android:id="@+id/single_class_2_indicator"'), isTrue);

        // Check height 28dp on indicators
        final ind1Regex = RegExp(r'android:id="@\+id/single_class_1_indicator"[^>]*?android:layout_height="28dp"');
        final ind2Regex = RegExp(r'android:id="@\+id/single_class_2_indicator"[^>]*?android:layout_height="28dp"');
        expect(ind1Regex.hasMatch(xml) || xml.contains('android:layout_height="28dp"'), isTrue);
        expect(ind2Regex.hasMatch(xml) || xml.contains('android:layout_height="28dp"'), isTrue);

        // Check font sizes (12.5sp and 9.5sp)
        expect(xml.contains('android:textSize="12.5sp"'), isTrue);
        expect(xml.contains('android:textSize="9.5sp"'), isTrue);
      });

      test('ScheduleWidgetProvider.kt implements extractEndTime and binds end times', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        expect(kt.contains('fun extractEndTime('), isTrue);
        expect(kt.contains('R.id.single_class_1_time_end'), isTrue);
        expect(kt.contains('R.id.single_class_2_time_end'), isTrue);
        expect(kt.contains('views.setTextViewText(R.id.single_class_1_time_end, c1TimeEnd)'), isTrue);
        expect(kt.contains('views.setTextViewText(R.id.single_class_2_time_end, c2TimeEnd)'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Đồng bộ Cột trái 2 mốc giờ trên iOS WidgetKit (Swift)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: iOS WidgetKit .systemMedium Parity', () {
      test('ScheduleWidgetKit.swift provides extractEndTime and renders 2 timestamps with 28dp capsule', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        expect(swift.contains('func extractEndTime('), isTrue);
        expect(swift.contains('VStack(alignment: .leading, spacing: 1)'), isTrue);
        expect(swift.contains('extractEndTime(c.timeSlot)'), isTrue);
        expect(swift.contains('Capsule()'), isTrue);
        expect(swift.contains('.frame(width: 3, height: 28)'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Khôi phục 100% Dữ Liệu Mẫu trong Live Preview Widget Studio
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Widget Studio Live Preview Always Uses Mock Sample Data', () {
      testWidgets('WidgetStudioScreen without explicit preview data displays Môn học 1..4 without querying DB', (tester) async {
        SharedPreferences.setMockInitialValues({
          'widget_theme_config': jsonEncode(WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day').toJson()),
        });

        await tester.binding.setSurfaceSize(const Size(450, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
            ],
            child: const MaterialApp(
              home: WidgetStudioScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display mock courses
        expect(find.text('Môn học 1'), findsOneWidget);
        expect(find.text('Môn học 2'), findsOneWidget);

        // Timeline start and end time rendered
        expect(find.text('7h'), findsWidgets); // Start time of Môn học 1
        expect(find.text('- 9h20'), findsWidgets); // End time of Môn học 1
        expect(find.text('9h30'), findsWidgets); // Start time of Môn học 2
        expect(find.text('- 11h55'), findsWidgets); // End time of Môn học 2
      });

      test('WidgetStudioScreen source code does not call ScheduleDb in _initData or _refreshScheduleDataForMode', () {
        final studioFile = File('lib/screens/widget_studio_screen.dart');
        expect(studioFile.existsSync(), isTrue);
        final content = studioFile.readAsStringSync();

        // Extract _initData function block
        final initDataStart = content.indexOf('Future<void> _initData() async {');
        expect(initDataStart != -1, isTrue);
        final initDataEnd = content.indexOf('void _syncPresetSelectionFromConfig()', initDataStart);
        final initDataBlock = content.substring(initDataStart, initDataEnd != -1 ? initDataEnd : initDataStart + 600);

        expect(initDataBlock.contains('ScheduleDb.getLichHoc'), isFalse);
        expect(initDataBlock.contains('ScheduleDb.getLichThi'), isFalse);

        // Extract _refreshScheduleDataForMode function block
        final refreshStart = content.indexOf('Future<void> _refreshScheduleDataForMode(');
        expect(refreshStart != -1, isTrue);
        final refreshEnd = content.indexOf('void _applyPreset(', refreshStart);
        final refreshBlock = content.substring(refreshStart, refreshEnd != -1 ? refreshEnd : refreshStart + 600);

        expect(refreshBlock.contains('ScheduleDb.getLichHoc'), isFalse);
        expect(refreshBlock.contains('ScheduleDb.getLichThi'), isFalse);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Apply Button Syncs Real Data & Preserves Mock Preview
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Apply Button Syncs Real Data & Keeps Live Preview Mock', () {
      testWidgets('Tapping Apply in Studio preserves mock preview', (tester) async {
        SharedPreferences.setMockInitialValues({
          'widget_theme_config': jsonEncode(WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day').toJson()),
        });

        await tester.binding.setSurfaceSize(const Size(450, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
            ],
            child: const MaterialApp(
              home: WidgetStudioScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Môn học 1'), findsOneWidget);

        final applyBtn = find.text('ÁP DỤNG CẤU HÌNH VÀO WIDGET');
        expect(applyBtn, findsOneWidget);
        await tester.tap(applyBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Live preview must still display Môn học 1
        expect(find.text('Môn học 1'), findsOneWidget);
        expect(find.text('✓ Đã cập nhật giao diện Widget'), findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Time Format Helpers & Zero Regressions
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: ScheduleCard formatStartHour and formatEndHour Utilities', () {
      test('ScheduleCard.formatEndHour formats end times correctly', () {
        expect(ScheduleCard.formatEndHour('06:55 – 09:20 (T1–3)'), equals('- 9h20'));
        expect(ScheduleCard.formatEndHour('09:30 – 11:55 (T4–6)'), equals('- 11h55'));
        expect(ScheduleCard.formatEndHour('12:55 – 17:05 (T8–12)'), equals('- 17h05'));
        expect(ScheduleCard.formatEndHour('17:15 – 19:40 (T13–15)'), equals('- 19h40'));
        expect(ScheduleCard.formatEndHour('07:00 – 11:00'), equals('- 11h'));
        expect(ScheduleCard.formatEndHour('7h - 11h'), equals('- 11h'));
        expect(ScheduleCard.formatEndHour('7h'), equals(''));
        expect(ScheduleCard.formatEndHour(''), equals(''));
      });
    });
  });
}
