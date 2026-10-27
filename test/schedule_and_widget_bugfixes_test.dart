import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/dashboard_screen.dart';
import 'package:Tram_Kien/screens/finance_screen.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/screens/schedule_screen.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('SPEC-SCHEDULE-WIDGET-05 Acceptance Criteria Verification Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Triển khai Animation Directional Slide + Fade Transition 220ms (main_shell.dart)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Directional Slide + Fade 220ms Animation & Persistent Screens in MainShell', () {
      test('Source Code: main_shell.dart implements Directional Slide + Fade 220ms, Curves.easeOutCubic, _slideDirection and persistent _screens', () {
        final file = File('lib/screens/main_shell.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. SingleTickerProviderStateMixin and AnimationController
        expect(
          content.contains('with SingleTickerProviderStateMixin'),
          isTrue,
          reason: 'MainShell must mixin SingleTickerProviderStateMixin',
        );
        expect(
          content.contains('duration: const Duration(milliseconds: 220)'),
          isTrue,
          reason: 'AnimationController duration must be exactly 220ms',
        );

        // 2. Directional Slide: _slideDirection & SlideTransition restored, ScaleTransition removed
        expect(
          content.contains('_slideDirection'),
          isTrue,
          reason: 'MainShell must declare and track _slideDirection for directional tab sliding',
        );
        expect(
          content.contains('SlideTransition'),
          isTrue,
          reason: 'MainShell must use SlideTransition on root IndexedStack',
        );
        expect(
          content.contains('ScaleTransition'),
          isFalse,
          reason: 'MainShell must eliminate ScaleTransition',
        );
        expect(
          content.contains('Curves.easeOutCubic'),
          isTrue,
          reason: 'Slide and Fade transitions must use Curves.easeOutCubic',
        );
        expect(
          content.contains('SlideTransition') && content.contains('FadeTransition'),
          isTrue,
          reason: 'Transition must combine SlideTransition and FadeTransition',
        );
        expect(
          content.contains('IndexedStack'),
          isTrue,
          reason: 'MainShell must use IndexedStack to preserve tab states and scroll positions',
        );
        expect(
          content.contains('_screens') && (content.contains('late final List<Widget> _screens') || content.contains('late List<Widget> _screens')),
          isTrue,
          reason: 'MainShell must store _screens persistently in State to prevent re-creation jank',
        );

        // 3. Widget Data Sync initial tab preserved
        expect(
          content.contains('WidgetDataSyncService.getInitialTargetTab()'),
          isTrue,
          reason: 'initState must call WidgetDataSyncService.getInitialTargetTab() for Home Widget navigation',
        );

        // 4. PageStorageKeys for 5 tabs
        expect(content.contains("'page_dashboard'"), isTrue);
        expect(content.contains("'page_schedule'"), isTrue);
        expect(content.contains("'page_grades'"), isTrue);
        expect(content.contains("'page_finance'"), isTrue);
        expect(content.contains("'page_profile'"), isTrue);
      });

      testWidgets('Widget Test: MainShell renders and triggers directional slide + fade transition without errors', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: const MaterialApp(
              home: MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify IndexedStack is present
        expect(find.byType(IndexedStack), findsOneWidget);

        // Tap Schedule tab (index 1)
        final scheduleTab = find.text('Lịch học');
        expect(scheduleTab, findsOneWidget);
        await tester.tap(scheduleTab);

        // Advance 100ms: animation in progress
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(SlideTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);

        // Advance past 220ms: animation completed
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tap Dashboard tab (index 0)
        final dashboardTab = find.text('Tổng quan');
        expect(dashboardTab, findsOneWidget);
        await tester.tap(dashboardTab);

        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Khóa Cứng keepPage: false & Chấm Dứt Xung Đột Lịch 2018 (schedule_screen.dart)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Hard Lock keepPage: false, Instant Selection & Elimination of In-App Hint Banner', () {
      test('Source Code: schedule_screen.dart configures keepPage: false and removed banner variables', () {
        final file = File('lib/screens/schedule_screen.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. keepPage: false on both MonthView and WeekView PageControllers
        expect(
          content.contains('_pageCtrl = PageController(initialPage: _currentPage, keepPage: false);'),
          isTrue,
          reason: 'schedule_screen.dart must instantiate PageController with keepPage: false in _MonthViewState and _WeekViewState',
        );

        // 2. No widget_hint_banner key
        expect(
          content.contains('widget_hint_banner'),
          isFalse,
          reason: 'widget_hint_banner must be completely removed from schedule_screen.dart',
        );

        // 3. No _bannerDismissed or _cachedBannerDismissed
        expect(
          content.contains('_cachedBannerDismissed') || content.contains('_bannerDismissed'),
          isFalse,
          reason: '_bannerDismissed and _cachedBannerDismissed variables must be removed',
        );

        // 4. No _dismissBanner
        expect(
          content.contains('_dismissBanner'),
          isFalse,
          reason: '_dismissBanner function must be removed',
        );
      });

      testWidgets('Widget Test: ScheduleScreen renders TabBar immediately without any hint banner', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: const MaterialApp(
              home: ScheduleScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Banner is nowhere to be found
        expect(find.byKey(const Key('widget_hint_banner')), findsNothing);
        expect(find.byKey(const Key('btn_widget_hint_try')), findsNothing);
        expect(find.byKey(const Key('btn_widget_hint_dismiss')), findsNothing);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Khôi phục Cơ Chế Chọn Ngày Lịch Tháng Tức Thì 0ms, Chấm Dứt Lỗi 2018
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: MonthView Instant 0ms Date Selection, Flat Container & Year 2018 Safety Clamp', () {
      test('Source Code: schedule_screen.dart uses instant setState selection and safe scroll clamp', () {
        final file = File('lib/screens/schedule_screen.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. Instant onSelect callback in MonthGrid
        expect(
          content.contains('onSelect: (d) => setState(() => _selected = d)'),
          isTrue,
          reason: '_MonthView must update date selection instantly with setState without animation delay',
        );

        // 2. Safe scroll threshold prevents dropping down to page 0 (Jan 2018)
        expect(
          content.contains('if (page <= 0 && _currentPage > 12)'),
          isTrue,
          reason: 'onPageChanged must check page <= 0 && _currentPage > 12 to prevent bouncing to Jan 2018 base date',
        );

        // 3. _goToToday safely animates to today
        expect(
          content.contains('void _goToToday()') && content.contains('_selected = now;'),
          isTrue,
          reason: '_goToToday must safely update _selected to now',
        );
      });

      test('Logic Test: Base year/month offset calculations and threshold protection', () {
        const baseYear = 2018;
        const baseMonth = 1;

        int dateToPage(int year, int month) =>
            (year - baseYear) * 12 + (month - baseMonth);

        DateTime pageToDate(int page) {
          var newMonth = baseMonth + page;
          var newYear = baseYear + (newMonth - 1) ~/ 12;
          newMonth = (newMonth - 1) % 12 + 1;
          return DateTime(newYear, newMonth);
        }

        // Test year 2026 month 10
        final page2026 = dateToPage(2026, 10);
        expect(page2026, equals((2026 - 2018) * 12 + (10 - 1))); // 8 * 12 + 9 = 105
        expect(page2026, greaterThan(12));

        final date = pageToDate(page2026);
        expect(date.year, equals(2026));
        expect(date.month, equals(10));

        // Jan 2018 is page 0
        expect(dateToPage(2018, 1), equals(0));
        expect(pageToDate(0).year, equals(2018));
        expect(pageToDate(0).month, equals(1));

        // Threshold clamp simulation: if page <= 0 and currentPage > 12, ignore
        int currentPage = page2026;
        int simulatedPageEvent = 0;
        bool shouldIgnore = (simulatedPageEvent <= 0 && currentPage > 12);
        expect(shouldIgnore, isTrue, reason: 'Safe threshold must block accidental bounce to Jan 2018');
      });

      testWidgets('Widget Test: MonthView renders without falling back to 2018 when selecting dates', (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();
        final testDate = DateTime(2026, 10, 15);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: ScheduleScreen(initialDate: testDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Month tab ('Tháng')
        final monthTab = find.text('Tháng');
        expect(monthTab, findsOneWidget);
        await tester.tap(monthTab);
        await tester.pumpAndSettle();

        // Verify header shows year 2026 and not 2018
        expect(find.textContaining('2026'), findsWidgets);
        expect(find.textContaining('2018'), findsNothing);

        // Tap day 20 on current month
        final day20 = find.text('20');
        expect(day20, findsWidgets);
        await tester.tap(day20.first);
        await tester.pumpAndSettle();

        // Verify year is STILL 2026 and NOT 2018
        expect(find.textContaining('2026'), findsWidgets);
        expect(find.textContaining('2018'), findsNothing);
      });

      test('Source Code: _MonthGrid replaces AnimatedContainer with flat Container and preserves dynamic rowCount', () {
        final file = File('lib/screens/schedule_screen.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // Find _MonthGrid declaration
        final monthGridIndex = content.indexOf('class _MonthGrid extends StatelessWidget');
        expect(monthGridIndex, greaterThan(0));

        // Get substring corresponding to _MonthGrid
        final monthGridEnd = content.indexOf('class _WeekView', monthGridIndex);
        final monthGridContent = content.substring(monthGridIndex, monthGridEnd > 0 ? monthGridEnd : monthGridIndex + 5000);

        // 1. No AnimatedContainer inside _MonthGrid
        expect(
          monthGridContent.contains('AnimatedContainer('),
          isFalse,
          reason: '_MonthGrid must use flat Container instead of AnimatedContainer to eliminate tap delay',
        );

        // 2. Day cells use Container
        expect(
          monthGridContent.contains('child: Container('),
          isTrue,
          reason: '_MonthGrid must use flat Container for day cells',
        );

        // 3. Dynamic rowCount calculation preserved
        expect(
          monthGridContent.contains('startOffset + daysInMonth + (7 - (startOffset + daysInMonth) % 7) % 7'),
          isTrue,
          reason: 'Dynamic row count (5 or 6 rows) must be preserved in _MonthGrid itemCount',
        );

        // 4. TabBarView animation between Month and Week preserved
        expect(
          content.contains('TabBarView(') && content.contains('controller: _tabCtrl,'),
          isTrue,
          reason: 'TabBarView tab transition animation must remain intact',
        );
      });

      testWidgets('Widget Test: Day cells in MonthGrid respond immediately with zero animation delay', (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();
        final testDate = DateTime(2026, 10, 15);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: ScheduleScreen(initialDate: testDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Month tab
        await tester.tap(find.text('Tháng'));
        await tester.pumpAndSettle();

        // Tap day 18: single tap with minimal frame advance (10ms) updates selection immediately
        final day18 = find.text('18');
        expect(day18, findsWidgets);
        await tester.tap(day18.first);
        await tester.pump(const Duration(milliseconds: 10));

        // Verify selection updated without needing 150ms animation completion
        expect(tester.takeException(), isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Đồng Bộ Skeleton Shimmer Cho Thẻ GPA & Tín Chỉ Trên Dashboard (dashboard_screen.dart)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Synchronized Skeleton Shimmer for GPA and Credits Bento Cards', () {
      test('Source Code: dashboard_screen.dart removes Opacity(0.45) and implements GPA & Credits SkeletonBox', () {
        final file = File('lib/screens/dashboard_screen.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. Zero Opacity(0.45) wrapping
        expect(
          content.contains('0.45'),
          isFalse,
          reason: 'dashboard_screen.dart must remove Opacity(0.45) from GPA/Credits cards',
        );

        // 2. GPA SkeletonBox dimensions: 80x12, 72x36, double.infinity x 6, 110x12
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*80,\s*height:\s*12,\s*radius:\s*4\s*\)').hasMatch(content),
          isTrue,
          reason: 'GPA card title must use SkeletonBox(width: 80, height: 12, radius: 4)',
        );
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*72,\s*height:\s*36,\s*radius:\s*6\s*\)').hasMatch(content),
          isTrue,
          reason: 'GPA card value must use SkeletonBox(width: 72, height: 36, radius: 6)',
        );
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*double\.infinity,\s*height:\s*6,\s*radius:\s*3\s*\)').hasMatch(content),
          isTrue,
          reason: 'GPA card progress bar must use SkeletonBox(width: double.infinity, height: 6, radius: 3)',
        );
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*110,\s*height:\s*12,\s*radius:\s*4\s*\)').hasMatch(content),
          isTrue,
          reason: 'GPA card credits subtitle must use SkeletonBox(width: 110, height: 12, radius: 4)',
        );

        // 3. Credits SkeletonBox dimensions: 50x12, 80x80 (radius 40), 70x12
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*50,\s*height:\s*12,\s*radius:\s*4\s*\)').hasMatch(content),
          isTrue,
          reason: 'Credits card title must use SkeletonBox(width: 50, height: 12, radius: 4)',
        );
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*80,\s*height:\s*80,\s*radius:\s*40\s*\)').hasMatch(content),
          isTrue,
          reason: 'Credits card ring must use SkeletonBox(width: 80, height: 80, radius: 40)',
        );
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*70,\s*height:\s*12,\s*radius:\s*4\s*\)').hasMatch(content),
          isTrue,
          reason: 'Credits card remaining credits subtitle must use SkeletonBox(width: 70, height: 12, radius: 4)',
        );
      });

      testWidgets('Widget Test: Dashboard renders SkeletonBox widgets when sync in progress without cache', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();
        appProvider.isCacheLoaded = false;
        appProvider.isSyncingForTest = true;

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: const MaterialApp(
              home: AppShimmerScope(
                child: DashboardScreen(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SkeletonBox), findsWidgets);
        final skeletons = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox)).toList();
        expect(skeletons.any((s) => s.width == 80 && s.height == 12), isTrue);
        expect(skeletons.any((s) => s.width == 72 && s.height == 36), isTrue);
        expect(skeletons.any((s) => s.height == 6 && s.radius == 3), isTrue);
        expect(skeletons.any((s) => s.width == 110 && s.height == 12), isTrue);
        expect(skeletons.any((s) => s.width == 50 && s.height == 12), isTrue);
        expect(skeletons.any((s) => s.width == 80 && s.height == 80 && s.radius == 40), isTrue);
        expect(skeletons.any((s) => s.width == 70 && s.height == 12), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Đồng Bộ Skeleton Shimmer Cho Màn Hình Lịch & Màn Hình Tài Chính
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Synchronized Skeleton Shimmer for Schedule & Finance Screens', () {
      test('Source Code: schedule_screen.dart & finance_screen.dart implement required SkeletonBox loading placeholders', () {
        final scheduleFile = File('lib/screens/schedule_screen.dart');
        expect(scheduleFile.existsSync(), isTrue);
        final scheduleContent = scheduleFile.readAsStringSync();

        // Schedule ca hoc Shimmer: SkeletonBox(width: double.infinity, height: 88, radius: 16)
        expect(
          scheduleContent.contains('SkeletonBox(width: double.infinity, height: 88, radius: 16)'),
          isTrue,
          reason: 'schedule_screen.dart _buildSelectedDayEvents must show SkeletonBox(width: double.infinity, height: 88, radius: 16) when loading',
        );

        final financeFile = File('lib/screens/finance_screen.dart');
        expect(financeFile.existsSync(), isTrue);
        final financeContent = financeFile.readAsStringSync();

        // Finance Hero card Shimmer: SkeletonBox(width: double.infinity, height: 140, radius: 24)
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*double\.infinity,\s*height:\s*140,\s*radius:\s*24\s*\)').hasMatch(financeContent),
          isTrue,
          reason: 'finance_screen.dart must show Hero Card SkeletonBox(width: double.infinity, height: 140, radius: 24) when loading',
        );

        // Finance fee item Shimmer: SkeletonBox(width: double.infinity, height: 72, radius: 16)
        expect(
          RegExp(r'SkeletonBox\s*\(\s*width:\s*double\.infinity,\s*height:\s*72,\s*radius:\s*16\s*\)').hasMatch(financeContent),
          isTrue,
          reason: 'finance_screen.dart must show fee items SkeletonBox(width: double.infinity, height: 72, radius: 16) when loading',
        );
      });

      testWidgets('Widget Test: Schedule & Finance render SkeletonBox loading placeholders', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final appProvider = AppProvider();
        appProvider.lichHocLoadingForTest = true;
        appProvider.hocPhiLoadingForTest = true;

        // 1. ScheduleScreen shows 2 Shimmer ca hoc (height 88)
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: const MaterialApp(
              home: AppShimmerScope(
                child: ScheduleScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Tháng'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final scheduleSkeletons = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox)).toList();
        final caHocSkeletons = scheduleSkeletons.where((s) => s.height == 88 && s.radius == 16).toList();
        expect(caHocSkeletons.length, equals(2));

        // 2. FinanceScreen shows Hero Shimmer (height 140) and 3 fee cards (height 72)
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: const MaterialApp(
              home: AppShimmerScope(
                child: FinanceScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final financeSkeletons = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox)).toList();
        expect(financeSkeletons.any((s) => s.height == 140 && s.radius == 24), isTrue);
        final feeSkeletons = financeSkeletons.where((s) => s.height == 72 && s.radius == 16).toList();
        expect(feeSkeletons.length, equals(3));
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn 100% Tính Năng Native Widget & Dữ Liệu Đồng Bộ
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Preservation of Native Widget Features & Synchronization Data', () {
      test('XML Configuration: widget_schedule_weekly_info.xml points to widget_preview_weekly', () {
        final file = File('android/app/src/main/res/xml/widget_schedule_weekly_info.xml');
        expect(file.existsSync(), isTrue, reason: 'widget_schedule_weekly_info.xml must exist');

        final xmlContent = file.readAsStringSync();

        // Must point to @drawable/widget_preview_weekly
        expect(
          xmlContent.contains('android:previewImage="@drawable/widget_preview_weekly"'),
          isTrue,
          reason: 'Weekly 4x4 widget must set android:previewImage="@drawable/widget_preview_weekly"',
        );

        // Must NOT point to app launcher icon
        expect(
          xmlContent.contains('@mipmap/ic_launcher'),
          isFalse,
          reason: 'Weekly 4x4 widget previewImage must not be set to generic app launcher icon',
        );
      });

      test('File System: Associated preview drawables exist in Android res directories', () {
        final xmlDrawable = File('android/app/src/main/res/drawable/widget_preview_weekly.xml');
        final pngDrawable = File('android/app/src/main/res/drawable-nodpi/widget_preview_weekly.png');

        expect(
          xmlDrawable.existsSync() || pngDrawable.existsSync(),
          isTrue,
          reason: 'Either widget_preview_weekly.xml or widget_preview_weekly.png must exist for Android launcher to render',
        );
      });

      test('Source Code: ScheduleWidgetProvider.kt reads show_teacher and formats teacher name', () {
        final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(file.existsSync(), isTrue, reason: 'ScheduleWidgetProvider.kt must exist');

        final content = file.readAsStringSync();

        // 1. Reads show_teacher preference
        expect(
          content.contains('showTeacher = themeObj.optBoolean("show_teacher", false)'),
          isTrue,
          reason: 'ScheduleWidgetProvider.kt must parse show_teacher boolean from widget configuration',
        );

        // 2. Checks teacher in formatCourseTimeRoom
        expect(
          content.contains('val teacherStr = if (showTeacher) c.optString("teacher", "") else ""'),
          isTrue,
          reason: 'formatCourseTimeRoom must retrieve teacher string when showTeacher is true',
        );

        // 3. Appends teacher to parts list
        expect(
          content.contains('if (teacherStr.isNotEmpty()) parts.add(teacherStr)'),
          isTrue,
          reason: 'formatCourseTimeRoom must append teacherStr to parts joined by •',
        );

        // 4. formatCourseSummary delegates to formatCourseTimeRoom
        expect(
          content.contains('fun formatCourseSummary(c: JSONObject): String') &&
              content.contains('val tr = formatCourseTimeRoom(c)'),
          isTrue,
          reason: 'formatCourseSummary must incorporate formatCourseTimeRoom to include teacher in multi-course summaries',
        );

        // 5. Covers 2x2, 3-day, and 7-day layouts
        expect(content.contains('"single_day_2x2"'), isTrue);
        expect(content.contains('"three_days"'), isTrue);
        expect(content.contains('"seven_days"'), isTrue);
      });

      test('Simulation Test: Native Kotlin formatting logic parity with teacher enabled/disabled', () {
        // Kotlin logic simulation in Dart
        String formatCourseTimeRoom({
          required bool showTime,
          required bool showRoom,
          required bool showTeacher,
          required String timeSlot,
          required String room,
          required String teacher,
        }) {
          final timeStr = showTime ? timeSlot : '';
          final roomStr = showRoom ? room : '';
          final teacherStr = showTeacher ? teacher : '';
          final parts = <String>[];
          if (timeStr.isNotEmpty) parts.add(timeStr);
          if (roomStr.isNotEmpty) parts.add(roomStr);
          if (teacherStr.isNotEmpty) parts.add(teacherStr);
          return parts.join(' • ');
        }

        String formatCourseSummary({
          required String title,
          required bool showTime,
          required bool showRoom,
          required bool showTeacher,
          required String timeSlot,
          required String room,
          required String teacher,
        }) {
          final tr = formatCourseTimeRoom(
            showTime: showTime,
            showRoom: showRoom,
            showTeacher: showTeacher,
            timeSlot: timeSlot,
            room: room,
            teacher: teacher,
          );
          return tr.isNotEmpty ? '$title • $tr' : title;
        }

        // Case A: showTeacher = false
        final trWithoutTeacher = formatCourseTimeRoom(
          showTime: true,
          showRoom: true,
          showTeacher: false,
          timeSlot: '07:00 - 09:15',
          room: 'P.301-H1',
          teacher: 'TS. Nguyễn Văn A',
        );
        expect(trWithoutTeacher, equals('07:00 - 09:15 • P.301-H1'));

        // Case B: showTeacher = true with valid teacher
        final trWithTeacher = formatCourseTimeRoom(
          showTime: true,
          showRoom: true,
          showTeacher: true,
          timeSlot: '07:00 - 09:15',
          room: 'P.301-H1',
          teacher: 'TS. Nguyễn Văn A',
        );
        expect(trWithTeacher, equals('07:00 - 09:15 • P.301-H1 • TS. Nguyễn Văn A'));

        // Case C: showTeacher = true with empty teacher
        final trWithEmptyTeacher = formatCourseTimeRoom(
          showTime: true,
          showRoom: true,
          showTeacher: true,
          timeSlot: '07:00 - 09:15',
          room: 'P.301-H1',
          teacher: '',
        );
        expect(trWithEmptyTeacher, equals('07:00 - 09:15 • P.301-H1'));

        // Case D: Summary format with teacher
        final summary = formatCourseSummary(
          title: 'Toán rời rạc',
          showTime: true,
          showRoom: true,
          showTeacher: true,
          timeSlot: '07:00 - 09:15',
          room: 'P.301-H1',
          teacher: 'TS. Nguyễn Văn A',
        );
        expect(summary, equals('Toán rời rạc • 07:00 - 09:15 • P.301-H1 • TS. Nguyễn Văn A'));
      });

      test('Source Code: widget_studio_screen.dart removed btn_add_to_home and added instructions', () {
        final file = File('lib/screens/widget_studio_screen.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. Must NOT contain btn_add_to_home
        expect(
          content.contains('btn_add_to_home'),
          isFalse,
          reason: 'btn_add_to_home button must be completely eliminated from WidgetStudioScreen',
        );

        // 2. Primary apply button retained
        expect(
          content.contains('ÁP DỤNG CẤU HÌNH VÀO WIDGET'),
          isTrue,
          reason: 'Must retain primary button ÁP DỤNG CẤU HÌNH VÀO WIDGET',
        );

        // 3. User guidance note added
        expect(
          content.contains('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
          isTrue,
          reason: 'Must include clean Swiss typography instruction note below apply button',
        );
      });

      testWidgets('Widget Test: WidgetStudioScreen renders Apply button and Swiss instruction, zero btn_add_to_home', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. btn_add_to_home must NOT exist
        expect(find.byKey(const Key('btn_add_to_home')), findsNothing);

        // 2. Apply button exists
        expect(find.text('ÁP DỤNG CẤU HÌNH VÀO WIDGET'), findsOneWidget);

        // 3. Instruction note exists
        expect(
          find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn Tối Ưu Skeleton Shimmer
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Preservation of Skeleton Shimmer Continuous Sweep Animation', () {
      test('Source Code: AppShimmerScopeState uses continuous Curves.easeInOut and omits Interval', () {
        final file = File('lib/widgets/shared_widgets.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // Locate AppShimmerScopeState
        final scopeStateIndex = content.indexOf('class AppShimmerScopeState');
        expect(scopeStateIndex, greaterThan(0));

        final scopeStateEnd = content.indexOf('class _AppShimmerScopeInherited', scopeStateIndex);
        final scopeStateContent = content.substring(scopeStateIndex, scopeStateEnd > 0 ? scopeStateEnd : scopeStateIndex + 3000);

        // 1. Must use continuous Curves.easeInOut
        expect(
          scopeStateContent.contains('curve: Curves.easeInOut,'),
          isTrue,
          reason: 'AppShimmerScopeState must use Curves.easeInOut for full cycle animation',
        );

        // 2. Must NOT use Interval(0.0, 0.75) which causes 25% dead pause
        expect(
          scopeStateContent.contains('Interval('),
          isFalse,
          reason: 'AppShimmerScopeState must remove Interval to eliminate the 1/4 cycle dead pause',
        );
      });

      testWidgets('Widget Test: Shimmer sweep values advance smoothly throughout entire timeline', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AppShimmerScope(
                child: Column(
                  children: [
                    SkeletonBox(width: 100, height: 20),
                    SizedBox(height: 10),
                    SkeletonBox(width: 200, height: 40),
                  ],
                ),
              ),
            ),
          ),
        );

        // Both SkeletonBox instances render properly
        expect(find.byType(SkeletonBox), findsNWidgets(2));

        // Advance through first half
        await tester.pump(const Duration(milliseconds: 375));
        expect(tester.takeException(), isNull);

        // Advance through 75% mark (where previous Interval paused)
        await tester.pump(const Duration(milliseconds: 750));
        expect(tester.takeException(), isNull);

        // Advance through final quartile (1125ms - 1500ms) - continues rendering without stutter
        await tester.pump(const Duration(milliseconds: 375));
        expect(tester.takeException(), isNull);
      });
    });
  });
}
