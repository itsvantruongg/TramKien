import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/widget_models.dart';
import '../lib/screens/widget_studio_screen.dart';

void main() {
  group('Iteration 20 - Task 1: Chuẩn hóa Text Header ("Lịch 7 ngày" -> "Lịch tuần")', () {
    test('1.1 lib/services/widget_data_sync_service.dart: title tuần là "Lịch tuần"', () {
      final file = File('lib/services/widget_data_sync_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("const String title = 'Lịch tuần';"), isTrue,
          reason: 'WidgetDataSyncService must assign title = "Lịch tuần" for weekly schedule');
      expect(content.contains("const String title = 'Lịch 7 ngày';"), isFalse,
          reason: 'Old title "Lịch 7 ngày" must be completely removed from WidgetDataSyncService');
    });

    test('1.2 android/app/src/main/res/layout/widget_schedule_weekly.xml: @+id/widget_weekly_title có text "Lịch tuần"', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('android:id="@+id/widget_weekly_title"'), isTrue);
      expect(content.contains('android:text="Lịch tuần"'), isTrue,
          reason: 'widget_schedule_weekly.xml default title text must be "Lịch tuần"');
    });

    test('1.3 ScheduleWidgetProvider.kt: Chuẩn hóa gán title = "Lịch tuần" khi seven_days hoặc chứa "7 ngày"/"tuần"', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('"seven_days", "weekly_strip" -> "Lịch tuần"'), isTrue,
          reason: 'defaultTitle for seven_days and weekly_strip must be "Lịch tuần"');
      expect(content.contains('layoutType == "seven_days" || rawTitle.contains("7 ngày", ignoreCase = true) || rawTitle.contains("tuần", ignoreCase = true)'), isTrue,
          reason: 'ScheduleWidgetProvider.kt must normalize any 7 ngày or tuần to "Lịch tuần"');
      expect(content.contains('title = "Lịch tuần"'), isTrue);
    });

    test('1.4 WidgetStudioScreen: Phân tách tiêu đề hiển thị đúng "Lịch tuần"', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("displayTitle = 'Lịch tuần';"), isTrue);
      expect(content.contains("displayTitle = (data.widgetTitle == 'Lịch 7 ngày' || isWeekly)"), isTrue);
      expect(content.contains("? 'Lịch tuần'"), isTrue);
    });
  });

  group('Iteration 20 - Task 2: Tăng Font Size Header to rõ, thẩm mỹ (Đồng bộ XML & Flutter Studio)', () {
    test('2.1 widget_schedule_weekly.xml: title 15.5sp, subtitle 11.5sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final titleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_weekly_title"'),
        content.indexOf('android:id="@+id/widget_weekly_subtitle"'),
      );
      expect(titleBlock.contains('android:textSize="15.5sp"'), isTrue,
          reason: 'Weekly widget title must have textSize 15.5sp');

      final subtitleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_weekly_subtitle"'),
        content.indexOf('android:id="@+id/widget_weekly_hairline"'),
      );
      expect(subtitleBlock.contains('android:textSize="11.5sp"'), isTrue,
          reason: 'Weekly widget subtitle must have textSize 11.5sp');
    });

    test('2.2 widget_schedule_three_days.xml: title 14sp, subtitle 11sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_three_days.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final titleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_title"'),
        content.indexOf('android:id="@+id/widget_subtitle"'),
      );
      expect(titleBlock.contains('android:textSize="14sp"'), isTrue,
          reason: 'Three-day widget title must have textSize 14sp');

      final subtitleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_subtitle"'),
        content.indexOf('android:id="@+id/widget_hairline"'),
      );
      expect(subtitleBlock.contains('android:textSize="11sp"'), isTrue,
          reason: 'Three-day widget subtitle must have textSize 11sp');
    });

    test('2.3 widget_schedule_single_day_2x2.xml: title 13sp, subtitle 11sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final titleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_title"'),
        content.indexOf('android:id="@+id/widget_subtitle"'),
      );
      expect(titleBlock.contains('android:textSize="13sp"'), isTrue,
          reason: 'Single-day 2x2 widget title must have textSize 13sp');

      final subtitleBlock = content.substring(
        content.indexOf('android:id="@+id/widget_subtitle"'),
        content.indexOf('android:id="@+id/widget_hairline"'),
      );
      expect(subtitleBlock.contains('android:textSize="11sp"'), isTrue,
          reason: 'Single-day 2x2 widget subtitle must have textSize 11sp');
    });

    test('2.4 WidgetStudioScreen: Đồng bộ TextStyle Header theo đúng công thức', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('fontSize: isWeeklyGrid ? 15.5 : (is2x2 ? 13 : 14),'), isTrue,
          reason: 'Studio title fontSize must match isWeeklyGrid ? 15.5 : (is2x2 ? 13 : 14)');
      expect(content.contains('fontSize: isWeeklyGrid ? 11.5 : 11,'), isTrue,
          reason: 'Studio subtitle fontSize must match isWeeklyGrid ? 11.5 : 11');
    });

    testWidgets('2.5 WidgetStudioScreen Live Preview renders correct title and font sizes for Single Day 4x2 Timeline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            key: const ValueKey('studio_single_day'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'single_day'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch hôm nay' && w.style?.fontFamily == 'Manrope');
      expect(titleFinder, findsOneWidget);
      final Text titleText = tester.widget(titleFinder);
      expect(titleText.style?.fontSize, 14.0);
    });

    testWidgets('2.6 WidgetStudioScreen Live Preview renders correct title and font sizes for 3 Days (4x2)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            key: const ValueKey('studio_3days'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'three_days'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch 3 ngày' && w.style?.fontFamily == 'Manrope');
      expect(titleFinder, findsOneWidget);
      final Text titleText = tester.widget(titleFinder);
      expect(titleText.style?.fontSize, 14.0);
    });

    testWidgets('2.7 WidgetStudioScreen Live Preview renders correct title and font sizes for Weekly (4x4)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            key: const ValueKey('studio_weekly'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'seven_days'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch tuần' && w.style?.fontFamily == 'Manrope');
      expect(titleFinder, findsOneWidget);
      final Text titleText = tester.widget(titleFinder);
      expect(titleText.style?.fontSize, 15.5);
    });
  });
}
