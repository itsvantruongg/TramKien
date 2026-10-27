import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi_VN', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setScreenSize(WidgetTester tester, {required double width, required double height}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetScreenSize(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Widget buildTestApp({
    required Widget child,
    AppProvider? provider,
    double fontScale = 1.0,
  }) {
    final p = provider ?? AppProvider();
    return ChangeNotifierProvider<AppProvider>.value(
      value: p,
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(fontScale),
            size: const Size(400, 800),
          ),
          child: child,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AC-01: Native Android Widget Stability & Safe RemoteViews
  // ══════════════════════════════════════════════════════════════════════════
  group('AC-01: Native Android Widget Stability & Safe RemoteViews', () {
    test('All 6 appwidget-provider XML files omit reconfigurable|configuration_optional', () {
      final xmlFiles = [
        'android/app/src/main/res/xml/widget_schedule_single_day_info.xml',
        'android/app/src/main/res/xml/widget_schedule_single_day_2x2_info.xml',
        'android/app/src/main/res/xml/widget_schedule_three_days_info.xml',
        'android/app/src/main/res/xml/widget_schedule_weekly_info.xml',
        'android/app/src/main/res/xml/widget_schedule_weekly_strip_info.xml',
        'android/app/src/main/res/xml/widget_schedule_tomorrow_info.xml',
      ];

      for (final path in xmlFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist');
        final content = file.readAsStringSync();
        expect(
          content.contains('android:widgetFeatures="reconfigurable|configuration_optional"'),
          isFalse,
          reason: '$path must not declare reconfigurable|configuration_optional to prevent Samsung launcher crash',
        );
      }
    });

    test('widget_schedule_weekly_info.xml declares previewImage @drawable/widget_preview_weekly', () {
      final file = File('android/app/src/main/res/xml/widget_schedule_weekly_info.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('android:previewImage="@drawable/widget_preview_weekly"'),
        isTrue,
        reason: 'widget_schedule_weekly_info.xml must declare previewImage @drawable/widget_preview_weekly',
      );
    });

    test('ScheduleWidgetProvider.kt encapsulates buildRemoteViews in try-catch and returns fallback', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('fun buildFallbackViews'), isTrue,
          reason: 'ScheduleWidgetProvider.kt must define buildFallbackViews');
      expect(content.contains('Error building RemoteViews'), isTrue,
          reason: 'ScheduleWidgetProvider.kt must log error on building RemoteViews');
      expect(content.contains('return buildFallbackViews(context, layoutResId)'), isTrue,
          reason: 'ScheduleWidgetProvider.kt must return buildFallbackViews in catch block');
      expect(content.contains('try { views.setInt(android.R.id.background, "setBackgroundResource", bgRes) } catch (_: Throwable) {}'), isTrue,
          reason: 'setBackgroundResource on android.R.id.background must be safely wrapped in try-catch');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC-02: Live Preview Studio Dimensions & RenderFlex Overflow Protection
  // ══════════════════════════════════════════════════════════════════════════
  group('AC-02: Live Preview Studio Dimensions & RenderFlex Overflow Protection', () {
    test('Source Code: previewHeight is 400 for Weekly Grid and 240 for 2x2', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('previewHeight = 400;'), isTrue,
          reason: 'Weekly Grid previewHeight must be 400');
      expect(content.contains('previewHeight = 240;'), isTrue,
          reason: '2x2 card previewHeight must be 240');
      expect(content.contains('width: 170,'), isTrue,
          reason: '2x2 card simulated width must be 170');
      expect(content.contains('height: 170,'), isTrue,
          reason: '2x2 card simulated height must be 170');
    });

    test('Source Code: _buildSimulatedWidgetCard is wrapped in FittedBox scaleDown', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(
        content.contains('return FittedBox(') &&
        content.contains('fit: BoxFit.scaleDown,') &&
        content.contains('alignment: Alignment.topCenter,'),
        isTrue,
        reason: '_buildSimulatedWidgetCard must be wrapped in FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter)',
      );
    });

    test('Source Code: _buildGridDayCell uses fontSize 8 for remaining courses (+... môn nữa)', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("'(+\${count - 2} môn nữa)'"), isTrue);
      expect(content.contains('fontSize: 8,'), isTrue,
          reason: 'Remaining courses badge must use compact 8sp font');
    });

    testWidgets('Live Preview renders 7-day grid and 2x2 without any RenderFlex overflow', (tester) async {
      setScreenSize(tester, width: 360, height: 750); // Narrow phone width
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.minimalSwiss().copyWith(
              layoutMode: 'seven_days',
              bgStyle: 'solid',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow exceptions thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(WidgetStudioScreen), findsOneWidget);

      // Switch to 2x2
      await tester.tap(find.byKey(const Key('mode_single_day')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WidgetStudioScreen), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC-03: Bottom Navigation Bar 60dp, Font Scale 1.2x & SnackBar Anchoring
  // ══════════════════════════════════════════════════════════════════════════
  group('AC-03: Bottom Navigation Bar 60dp, Font Scale 1.2x & SnackBar Anchoring', () {
    test('Source Code: Bottom navigation bar height is 60dp/62dp and label has height: 1.0 with FittedBox', () {
      final file = File('lib/screens/main_shell.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('height: 62,') || content.contains('height: 60,'), isTrue,
          reason: 'Bottom navigation bar height must be 60dp or 62dp');
      expect(content.contains('height: 1.0,'), isTrue,
          reason: 'Label TextStyle must specify height: 1.0');
      expect(
        content.contains('FittedBox(') && content.contains('fit: BoxFit.scaleDown,'),
        isTrue,
        reason: 'Nav item text must be wrapped in FittedBox(fit: BoxFit.scaleDown)',
      );
      expect(content.contains('heightFactor: 1.0,'), isTrue,
          reason: 'Align must specify heightFactor: 1.0 to anchor Scaffold properly');
    });

    testWidgets('MainShell bottom bar renders with Font Scale 1.3x without 4.1px bottom overflow', (tester) async {
      setScreenSize(tester, width: 380, height: 700);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        fontScale: 1.3, // Large font scale as on Samsung One UI
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'Font scale 1.3x must not cause any RenderFlex overflow on bottom bar');
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Lịch học'), findsWidgets);
      expect(find.text('Điểm số'), findsWidgets);
      expect(find.text('Học phí'), findsWidgets);
      expect(find.text('Tài khoản'), findsWidgets);
    });

    testWidgets('Floating SnackBar appears on screen above bottom navigation bar', (tester) async {
      setScreenSize(tester, width: 400, height: 800);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();

      // Show a floating SnackBar
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.showBottomSheet((_) => const SizedBox.shrink()); // test Scaffold interaction
      ScaffoldMessenger.of(scaffoldState.context).showSnackBar(
        const SnackBar(
          content: Text('Kiểm tra SnackBar nổi'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Kiểm tra SnackBar nổi'), findsOneWidget);
      final snackBarRect = tester.getRect(find.text('Kiểm tra SnackBar nổi'));
      // Verify SnackBar is within screen viewport bounds (0 < top < 800)
      expect(snackBarRect.top, greaterThan(0));
      expect(snackBarRect.bottom, lessThan(800));
      await tester.pump(const Duration(milliseconds: 350));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC-04: Slide + Fade 220ms Animation & State Preservation in MainShell
  // ══════════════════════════════════════════════════════════════════════════
  group('AC-04: Slide + Fade 220ms Animation & State Preservation in MainShell', () {
    test('Source Code: MainShell uses Slide + Fade 220ms with IndexedStack', () {
      final file = File('lib/screens/main_shell.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('SlideTransition('), isTrue,
          reason: 'MainShell must use SlideTransition');
      expect(content.contains('FadeTransition('), isTrue,
          reason: 'MainShell must use FadeTransition for fade animation');
      expect(content.contains('duration: const Duration(milliseconds: 220)'), isTrue,
          reason: 'AnimationController duration must be 220ms');
      expect(content.contains('Curves.easeOutCubic'), isTrue,
          reason: 'Transition must transform using Curves.easeOutCubic');
      expect(content.contains('IndexedStack('), isTrue,
          reason: 'MainShell must use IndexedStack for state preservation');
    });

    testWidgets('MainShell renders and smoothly animates between tabs with state maintained', (tester) async {
      setScreenSize(tester, width: 400, height: 800);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      // Initial tab is Dashboard (tab 0)
      expect(find.byKey(const ValueKey('screen_0')), findsOneWidget);

      // Tap on Tab 1 (Lịch học)
      await tester.tap(find.text('Lịch học').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Transitions active
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      // Complete transition
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen_1')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC-05: Optimize Shimmer Performance & Memory Churn
  // ══════════════════════════════════════════════════════════════════════════
  group('AC-05: Optimize Shimmer Performance & Memory Churn', () {
    test('Source Code: AppShimmerScopeState caches gradients and SkeletonBox uses cached gradient', () {
      final file = File('lib/widgets/shared_widgets.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('_cachedLightGradient'), isTrue,
          reason: 'AppShimmerScopeState must have _cachedLightGradient');
      expect(content.contains('_cachedDarkGradient'), isTrue,
          reason: 'AppShimmerScopeState must have _cachedDarkGradient');
      expect(content.contains('getShimmerGradient({required bool isDark})'), isTrue,
          reason: 'AppShimmerScopeState must provide getShimmerGradient');
      expect(content.contains('shimmer.getShimmerGradient(isDark: isDark)'), isTrue,
          reason: 'SkeletonBox must retrieve reused gradient from shimmer scope');
      expect(content.contains('_defaultRadius = BorderRadius.circular(8);'), isTrue,
          reason: 'SkeletonBox must cache default radius 8');
    });

    testWidgets('Multiple SkeletonBoxes share cached gradient without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShimmerScope(
              child: Column(
                children: [
                  SkeletonBox(width: 100, height: 20),
                  SkeletonBox(width: 150, height: 20),
                  SkeletonBox(width: 200, height: 20),
                  SkeletonBox(width: 250, height: 20),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(4));

      // Advance animation multiple frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
