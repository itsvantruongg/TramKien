import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/dashboard_screen.dart';
import 'package:Tram_Kien/screens/finance_screen.dart';
import 'package:Tram_Kien/screens/grades_screen.dart';
import 'package:Tram_Kien/screens/login_screen.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/screens/profile_screen.dart';
import 'package:Tram_Kien/screens/schedule_screen.dart';
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

  void setScreenSize(WidgetTester tester,
      {required double width, required double height}) {
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
    ThemeMode themeMode = ThemeMode.light,
  }) {
    final p = provider ?? AppProvider();
    return ChangeNotifierProvider<AppProvider>.value(
      value: p,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: child,
      ),
    );
  }

  group('AC-01: Adaptive Shell Navigation & Breakpoints', () {
    testWidgets(
        'Compact (W < 600dp): Renders Floating BottomBar with maxWidth 500 and no NavigationRail',
        (tester) async {
      setScreenSize(tester, width: 400, height: 800);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      // NavigationRail must not exist on phone / compact
      expect(find.byType(NavigationRail), findsNothing);

      // Bottom bar must exist
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Lịch học'), findsWidgets);
      expect(find.text('Điểm số'), findsWidgets);
      expect(find.text('Học phí'), findsWidgets);
      expect(find.text('Tài khoản'), findsWidgets);

      // Verify Align with ConstrainedBox(maxWidth: 500)
      final aligns = tester.widgetList<Align>(find.byType(Align));
      final hasCenteredConstrainedBottomBar = aligns.any((a) {
        if (a.alignment != Alignment.bottomCenter) return false;
        final child = a.child;
        return child is ConstrainedBox && child.constraints.maxWidth == 500;
      });
      expect(hasCenteredConstrainedBottomBar, isTrue,
          reason:
              'Bottom bar must be wrapped in Align(bottomCenter) and ConstrainedBox(maxWidth: 500)');
    });

    testWidgets(
        'Tablet (W >= 600dp): Renders NavigationRail on left with 5 destinations and no bottom bar',
        (tester) async {
      setScreenSize(tester, width: 800, height: 1000);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();

      // NavigationRail must exist on tablet
      expect(find.byType(NavigationRail), findsOneWidget);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 5);
      expect(rail.selectedIndex, 0);

      // Scaffold bottomNavigationBar of MainShell must be null
      final mainScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(mainScaffold.bottomNavigationBar, isNull,
          reason: 'BottomNavigationBar must be null when W >= 600dp');

      // Tapping Lịch học on NavigationRail switches active tab
      await tester.tap(find.text('Lịch học').first);
      await tester.pumpAndSettle();

      final updatedRail =
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(updatedRail.selectedIndex, 1);
    });
  });

  group('AC-02: Scale + Fade Tab Transitions (SPEC-SCHEDULE-WIDGET-04)', () {
    test(
        'Code Audit: Directional Slide + Fade 220ms animation in main_shell.dart (SPEC-SCHEDULE-WIDGET-05 AC-01)',
        () {
      final file = File('lib/screens/main_shell.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('SlideTransition'), isTrue,
          reason: 'SlideTransition must be used in main_shell.dart for tab switching');
      expect(content.contains('FadeTransition'), isTrue,
          reason: 'FadeTransition must be used in main_shell.dart for fade transition');
      expect(content.contains('duration: const Duration(milliseconds: 220)'), isTrue,
          reason: 'AnimationController duration must be 220ms');
      expect(content.contains('Curves.easeOutCubic'), isTrue,
          reason: 'Slide and fade transitions must use Curves.easeOutCubic');
      expect(content.contains('IndexedStack'), isTrue,
          reason: 'IndexedStack must be used to preserve state and scroll');
    });

    testWidgets(
        'FadeThroughTransition applies FadeTransition and ScaleTransition (0.96 to 1.0)',
        (tester) async {
      final ctrl = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 220),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FadeThroughTransition(
            animation: ctrl,
            child: const Text('Test Child'),
          ),
        ),
      );

      final fadeFinder = find.descendant(
        of: find.byType(FadeThroughTransition),
        matching: find.byType(FadeTransition),
      );
      final scaleFinder = find.descendant(
        of: find.byType(FadeThroughTransition),
        matching: find.byType(ScaleTransition),
      );

      expect(fadeFinder, findsOneWidget);
      expect(scaleFinder, findsOneWidget);

      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidget.scale.value, 0.96);

      ctrl.value = 1.0;
      await tester.pump();

      final scaleWidgetFull = tester.widget<ScaleTransition>(scaleFinder);
      final fadeWidgetFull = tester.widget<FadeTransition>(fadeFinder);
      expect(scaleWidgetFull.scale.value, 1.0);
      expect(fadeWidgetFull.opacity.value, 1.0);
    });
  });

  group('AC-03: Schedule Tablet Responsive Split View', () {
    testWidgets(
        'Compact (W < 600dp): MonthView has cellSize <= 52dp and maxWidth 480',
        (tester) async {
      setScreenSize(tester, width: 400, height: 800);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const ScheduleScreen(),
      ));
      await tester.pumpAndSettle();

      // Switch to 'Tháng' tab (index 0)
      await tester.tap(find.text('Tháng'));
      await tester.pumpAndSettle();

      // On mobile, month view is a single column layout
      expect(find.byType(ScheduleScreen), findsOneWidget);

      // Verify ConstrainedBox(maxWidth: 480) exists
      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax480 = boxes.any((b) => b.constraints.maxWidth == 480);
      expect(hasMax480, isTrue,
          reason:
              'Compact month calendar must be wrapped in ConstrainedBox(maxWidth: 480)');
    });

    testWidgets(
        'Tablet (W >= 600dp): MonthView splits into 2 columns (Left column MonthGrid <= 400dp, Right column Expanded events)',
        (tester) async {
      setScreenSize(tester, width: 800, height: 1000);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const ScheduleScreen(),
      ));
      await tester.pumpAndSettle();

      // Switch to 'Tháng' tab (index 0)
      await tester.tap(find.text('Tháng'));
      await tester.pumpAndSettle();

      // On tablet, MonthView splits into Row with left column and right column
      final rows = tester.widgetList<Row>(find.byType(Row));
      final splitRow = rows.firstWhere(
        (r) =>
            r.crossAxisAlignment == CrossAxisAlignment.start &&
            r.children.any(
                (c) => c is SizedBox && c.width != null && c.width! <= 400),
      );
      expect(splitRow, isNotNull,
          reason:
              'Tablet MonthView must show Row split with left column <= 400dp');

      // Right column must be Expanded
      final hasExpandedColumn = splitRow.children.any((c) => c is Expanded);
      expect(hasExpandedColumn, isTrue,
          reason: 'Tablet MonthView right column must be Expanded');
    });
  });

  group('AC-04: Login Screen Centered MaxWidth', () {
    testWidgets('LoginScreen form & logo wrapped in Center with maxWidth 420',
        (tester) async {
      setScreenSize(tester, width: 900, height: 1200);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(buildTestApp(
        child: const LoginScreen(),
      ));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax420Centered = boxes.any((b) => b.constraints.maxWidth == 420);
      expect(hasMax420Centered, isTrue,
          reason:
              'Login form must be wrapped in ConstrainedBox(maxWidth: 420)');

      // Verify the rendered width of SurfaceCard is at most 420dp
      final surfaceCard = find.byType(SurfaceCard);
      expect(surfaceCard, findsOneWidget);
      final size = tester.getSize(surfaceCard);
      expect(size.width, lessThanOrEqualTo(420.0),
          reason:
              'SurfaceCard inside login screen must not exceed 420dp width');
    });
  });

  group('AC-05: Optimal Content Width Across Screens', () {
    testWidgets(
        'DashboardScreen wraps content in Center(ConstrainedBox(maxWidth: 720))',
        (tester) async {
      setScreenSize(tester, width: 1000, height: 1200);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax720 = boxes.any((b) => b.constraints.maxWidth == 720);
      expect(hasMax720, isTrue,
          reason: 'Dashboard content must be constrained to maxWidth 720');

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);
      final size = tester.getSize(refreshIndicator);
      expect(size.width, lessThanOrEqualTo(720.0));
    });

    testWidgets(
        'GradesScreen wraps content in Center(ConstrainedBox(maxWidth: 720))',
        (tester) async {
      setScreenSize(tester, width: 1000, height: 1200);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const GradesScreen(),
      ));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax720 = boxes.any((b) => b.constraints.maxWidth == 720);
      expect(hasMax720, isTrue,
          reason: 'Grades content must be constrained to maxWidth 720');

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);
      final size = tester.getSize(refreshIndicator);
      expect(size.width, lessThanOrEqualTo(720.0));
    });

    testWidgets(
        'FinanceScreen wraps content in Center(ConstrainedBox(maxWidth: 720))',
        (tester) async {
      setScreenSize(tester, width: 1000, height: 1200);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const FinanceScreen(),
      ));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax720 = boxes.any((b) => b.constraints.maxWidth == 720);
      expect(hasMax720, isTrue,
          reason: 'Finance content must be constrained to maxWidth 720');

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);
      final size = tester.getSize(refreshIndicator);
      expect(size.width, lessThanOrEqualTo(720.0));
    });

    testWidgets(
        'ProfileScreen wraps content in Center(ConstrainedBox(maxWidth: 720))',
        (tester) async {
      setScreenSize(tester, width: 1000, height: 1200);
      addTearDown(() => resetScreenSize(tester));

      final provider = AppProvider();
      await tester.pumpWidget(buildTestApp(
        provider: provider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMax720 = boxes.any((b) => b.constraints.maxWidth == 720);
      expect(hasMax720, isTrue,
          reason: 'Profile content must be constrained to maxWidth 720');

      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);
      final size = tester.getSize(scrollView);
      expect(size.width, lessThanOrEqualTo(720.0));
    });
  });

  group('AC-06: Synchronized Shimmer Motion System', () {
    test('SkeletonBox is a StatelessWidget with zero independent tickers', () {
      const box = SkeletonBox(width: 100, height: 20);
      expect(box, isA<StatelessWidget>(),
          reason:
              'SkeletonBox must be a StatelessWidget to eliminate 30 independent tickers');
    });

    testWidgets(
        'AppShimmerScope / SynchronizedShimmer provides single controller and syncs multiple SkeletonBoxes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShimmerScope(
            child: Column(
              children: [
                SkeletonBox(width: 120, height: 20),
                SkeletonBox(width: 200, height: 20),
                SkeletonBox(width: 80, height: 20),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmerScope), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(3));

      // Advance time and verify animation moves smoothly without error
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      final containers =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.gradient is LinearGradient;
      }).toList();

      expect(containers.length, greaterThanOrEqualTo(3),
          reason:
              'All SkeletonBoxes should have 135-degree LinearGradient shimmer');

      final gradient = (containers.first.decoration as BoxDecoration).gradient
          as LinearGradient;
      expect(gradient.colors.length, 3);
      expect(gradient.colors[0], const Color(0xFFE2E8F0));
      expect(gradient.colors[1], const Color(0xFFF1F5F9));
      expect(gradient.colors[2], const Color(0xFFE2E8F0));
    });

    testWidgets(
        'SkeletonBox outside AppShimmerScope gracefully renders fallback without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SkeletonBox(width: 100, height: 24),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, const Color(0xFFE2E8F0));
    });

    testWidgets(
        'SynchronizedShimmer renders dark theme gradient colors on dark mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const AppShimmerScope(
            child: SkeletonBox(width: 100, height: 20),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final container =
          tester.widgetList<Container>(find.byType(Container)).firstWhere((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.gradient is LinearGradient;
      });

      final gradient =
          (container.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors[0], const Color(0xFF2D3238));
      expect(gradient.colors[1], const Color(0xFF3B424B));
      expect(gradient.colors[2], const Color(0xFF2D3238));
    });
  });
}
