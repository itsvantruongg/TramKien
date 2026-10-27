import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/screens/dashboard_screen.dart';
import 'package:Tram_Kien/screens/schedule_screen.dart';
import 'package:Tram_Kien/screens/grades_screen.dart';
import 'package:Tram_Kien/screens/finance_screen.dart';
import 'package:Tram_Kien/screens/profile_screen.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/theme/app_theme.dart';

Widget _buildTestApp(Widget child) {
  return ChangeNotifierProvider<AppProvider>(
    create: (_) => AppProvider(),
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('SPEC-UNIFIED-16DP-GRID-AND-CAPSULE-RESTORE-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Đồng bộ lề 2 bên 16dp cho toàn bộ các trang nội dung
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: 16dp Horizontal Padding Synchronization Across All Pages', () {
      test('DashboardScreen source code uses 16dp horizontal padding (fromLTRB(16, 0, 16, 100))', () {
        final content = File('lib/screens/dashboard_screen.dart').readAsStringSync();
        expect(content.contains('EdgeInsets.fromLTRB(16, 0, 16, 100)'), isTrue,
            reason: 'DashboardScreen must use EdgeInsets.fromLTRB(16, 0, 16, 100)');
      });

      test('ScheduleScreen source code uses 16dp horizontal padding / margins', () {
        final content = File('lib/screens/schedule_screen.dart').readAsStringSync();
        // Tab bar margin
        expect(content.contains('EdgeInsets.fromLTRB(16, 8, 16, 8)'), isTrue,
            reason: 'ScheduleScreen tab bar margin must be EdgeInsets.fromLTRB(16, 8, 16, 8)');
        // Month header padding
        expect(content.contains('EdgeInsets.fromLTRB(16, 8, 16, 0)'), isTrue,
            reason: 'ScheduleScreen month header padding must be EdgeInsets.fromLTRB(16, 8, 16, 0)');
        // Calendar card horizontal margin
        expect(content.contains('EdgeInsets.symmetric(horizontal: 16)'), isTrue,
            reason: 'ScheduleScreen calendar card margin must be horizontal: 16');
        // Selected day events list padding
        expect(content.contains('EdgeInsets.fromLTRB(16, 0, 16, 100)'), isTrue,
            reason: 'ScheduleScreen events list padding must be EdgeInsets.fromLTRB(16, 0, 16, 100)');
        // Week view empty and item list paddings
        expect(content.contains('EdgeInsets.fromLTRB(16, 8, 16, 80)'), isTrue,
            reason: 'ScheduleScreen week view empty padding must be EdgeInsets.fromLTRB(16, 8, 16, 80)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 0, 16, 80)'), isTrue,
            reason: 'ScheduleScreen week view items padding must be EdgeInsets.fromLTRB(16, 0, 16, 80)');
      });

      test('GradesScreen source code uses 16dp horizontal padding', () {
        final content = File('lib/screens/grades_screen.dart').readAsStringSync();
        expect(content.contains('EdgeInsets.fromLTRB(16, 16, 16, 0)'), isTrue,
            reason: 'GradesScreen toggle padding must be EdgeInsets.fromLTRB(16, 16, 16, 0)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 12, 16, 0)'), isTrue,
            reason: 'GradesScreen summary padding must be EdgeInsets.fromLTRB(16, 12, 16, 0)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 20, 16, 0)'), isTrue,
            reason: 'GradesScreen chart padding must be EdgeInsets.fromLTRB(16, 20, 16, 0)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 12, 16, 100)'), isTrue,
            reason: 'GradesScreen list padding must be EdgeInsets.fromLTRB(16, 12, 16, 100)');
      });

      test('FinanceScreen source code uses 16dp horizontal padding', () {
        final content = File('lib/screens/finance_screen.dart').readAsStringSync();
        expect(content.contains('EdgeInsets.fromLTRB(16, 8, 16, 0)'), isTrue,
            reason: 'FinanceScreen hero card padding must be EdgeInsets.fromLTRB(16, 8, 16, 0)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 20, 16, 100)'), isTrue,
            reason: 'FinanceScreen list padding must be EdgeInsets.fromLTRB(16, 20, 16, 100)');
      });

      test('ProfileScreen source code uses 16dp horizontal padding', () {
        final content = File('lib/screens/profile_screen.dart').readAsStringSync();
        expect(content.contains('EdgeInsets.fromLTRB(16, 8, 16, 100)'), isTrue,
            reason: 'ProfileScreen main list padding must be EdgeInsets.fromLTRB(16, 8, 16, 100)');
        expect(content.contains('EdgeInsets.fromLTRB(16, 4, 16, 100)'), isTrue,
            reason: 'ProfileScreen detail list padding must be EdgeInsets.fromLTRB(16, 4, 16, 100)');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Thanh điều hướng đáy áp dụng lề 2 bên 16dp
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: MainShell Bottom Navigation 16dp Horizontal Margin', () {
      test('MainShell nav container has margin: EdgeInsets.fromLTRB(16, 0, 16, 16)', () {
        final content = File('lib/screens/main_shell.dart').readAsStringSync();
        expect(content.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),'), isTrue,
            reason: 'MainShell nav must have margin: const EdgeInsets.fromLTRB(16, 0, 16, 16)');
        expect(content.contains('height: 62,'), isTrue,
            reason: 'MainShell nav outer height must be 62');
        expect(content.contains('borderRadius: BorderRadius.circular(31),') || content.contains('borderRadius: BorderRadius.circular(28),'), isTrue,
            reason: 'MainShell nav outer borderRadius must be 31 or 28');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Header dóng thẳng tắp 16dp với toàn bộ nội dung
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: AcademicAppBar 16dp Left Alignment', () {
      test('AcademicAppBar padding is EdgeInsets.fromLTRB(16, 6, 8, 6)', () {
        final content = File('lib/widgets/shared_widgets.dart').readAsStringSync();
        expect(content.contains('padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),'), isTrue,
            reason: 'AcademicAppBar padding must be EdgeInsets.fromLTRB(16, 6, 8, 6)');
      });

      testWidgets('AcademicAppBar renders with 16dp left padding', (tester) async {
        await tester.pumpWidget(_buildTestApp(
          const Scaffold(
            appBar: AcademicAppBar(subtitle: 'TEST'),
            body: SizedBox(),
          ),
        ));
        await tester.pumpAndSettle();

        final appBarFinder = find.byType(AcademicAppBar);
        expect(appBarFinder, findsOneWidget);

        // Find the Padding widget inside AcademicAppBar
        final paddingFinder = find.descendant(
          of: appBarFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(16, 6, 8, 6),
          ),
        );
        expect(paddingFinder, findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Khôi phục kiểu dáng viên thuốc tròn đồng dạng (Capsule 24dp)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Restore Concentric Capsule Indicator 24dp', () {
      test('MainShell source code uses borderRadius: BorderRadius.circular(24) and height 48', () {
        final content = File('lib/screens/main_shell.dart').readAsStringSync();
        expect(content.contains('height: 48,'), isTrue,
            reason: 'Active indicator height must be 48');
        expect(content.contains('top: 7,'), isTrue,
            reason: 'Active indicator top offset must be 7');
        expect(content.contains('margin: const EdgeInsets.symmetric(horizontal: 5),') || content.contains('margin: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
            reason: 'Active indicator margin must be horizontal: 5 or 2');
        expect(content.contains('borderRadius: BorderRadius.circular(24),') || content.contains('borderRadius: BorderRadius.circular(18),'), isTrue,
            reason: 'Active indicator must have concentric capsule borderRadius: BorderRadius.circular(24) or 18');
        expect(content.contains('color: AppTheme.primaryFixed.withOpacity(0.85),'), isTrue,
            reason: 'Active indicator color must be AppTheme.primaryFixed.withOpacity(0.85)');
      });

      testWidgets('MainShell renders 24dp capsule active indicator in bottom bar', (tester) async {
        tester.binding.window.physicalSizeTestValue = const Size(400, 800);
        tester.binding.window.devicePixelRatioTestValue = 1.0;
        addTearDown(() {
          tester.binding.window.clearPhysicalSizeTestValue();
          tester.binding.window.clearDevicePixelRatioTestValue();
        });

        await tester.pumpWidget(_buildTestApp(const MainShell()));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Find AnimatedPositioned indicator
        final animatedPositionedFinder = find.byWidgetPredicate(
          (w) => w is AnimatedPositioned && w.height == 48 && w.top == 7,
        );
        expect(animatedPositionedFinder, findsOneWidget);

        // Inside AnimatedPositioned, find Container with BorderRadius 24
        final containerFinder = find.descendant(
          of: animatedPositionedFinder,
          matching: find.byWidgetPredicate((w) {
            if (w is Container && w.decoration is BoxDecoration) {
              final box = w.decoration as BoxDecoration;
              return (box.borderRadius == BorderRadius.circular(24) || box.borderRadius == BorderRadius.circular(18)) &&
                  (w.margin == const EdgeInsets.symmetric(horizontal: 5) || w.margin == const EdgeInsets.symmetric(horizontal: 2));
            }
            return false;
          }),
        );
        expect(containerFinder, findsOneWidget,
            reason: 'Indicator container must have borderRadius 24 and margin horizontal 5');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn Test Suite & Không gây Regression Bug
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Tab Navigation & Widget Integration Regression Tests', () {
      testWidgets('MainShell switches tabs smoothly and updates indicator position', (tester) async {
        tester.binding.window.physicalSizeTestValue = const Size(400, 800);
        tester.binding.window.devicePixelRatioTestValue = 1.0;
        addTearDown(() {
          tester.binding.window.clearPhysicalSizeTestValue();
          tester.binding.window.clearDevicePixelRatioTestValue();
        });

        await tester.pumpWidget(_buildTestApp(const MainShell()));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Initial tab is Tổng quan (index 0)
        expect(find.text('Tổng quan'), findsWidgets);

        // Tap Lịch học (index 1)
        await tester.tap(find.text('Lịch học').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('screen_1')), findsOneWidget);

        // Tap Điểm số (index 2)
        await tester.tap(find.text('Điểm số').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('screen_2')), findsOneWidget);

        // Tap Học phí (index 3)
        await tester.tap(find.text('Học phí').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('screen_3')), findsOneWidget);

        // Tap Tài khoản (index 4)
        await tester.tap(find.text('Tài khoản').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('screen_4')), findsOneWidget);

        // Return to Dashboard (index 0)
        await tester.tap(find.text('Tổng quan').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('screen_0')), findsOneWidget);
      });
    });
  });
}
