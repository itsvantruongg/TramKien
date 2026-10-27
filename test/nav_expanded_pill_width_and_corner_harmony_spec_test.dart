import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/theme/app_theme.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SPEC-NAV-EXPANDED-PILL-WIDTH-AND-CORNER-HARMONY-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Nới rộng chiều ngang viên thuốc xanh con (margin ngang 2dp)
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-01: Source Code Audit - Indicator con có margin ngang 2dp (tăng thêm 6dp chiều ngang)', () {
      final shellFile = File('lib/screens/main_shell.dart');
      expect(shellFile.existsSync(), isTrue, reason: 'main_shell.dart must exist');
      final shellContent = shellFile.readAsStringSync();

      // Margin ngang 2dp để nới rộng width thêm 6dp
      expect(
        shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 2),'),
        isTrue,
        reason: 'Indicator child container must have margin: const EdgeInsets.symmetric(horizontal: 2)',
      );

      // Width indicator gắn với itemWidth
      expect(shellContent.contains('width: itemWidth,'), isTrue,
          reason: 'Indicator width must be itemWidth');
      expect(shellContent.contains('final itemWidth = constraints.maxWidth / 5;'), isTrue,
          reason: 'itemWidth must divide maxWidth by 5 tabs');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Cân chỉnh góc bo viên thuốc trong thành 18dp
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-02: Source Code Audit - Khối indicator bên trong áp dụng BorderRadius.circular(18)', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Indicator inner borderRadius 18dp
      expect(
        shellContent.contains('borderRadius: BorderRadius.circular(18),'),
        isTrue,
        reason: 'Indicator container must use BorderRadius.circular(18)',
      );

      // Indicator chiều cao 48dp, top 7dp
      expect(shellContent.contains('height: 48,'), isTrue,
          reason: 'Indicator height must be 48dp');
      expect(shellContent.contains('top: 7,'), isTrue,
          reason: 'Indicator top must be 7dp');

      // Màu nền indicator
      expect(
        shellContent.contains('color: AppTheme.primaryFixed.withOpacity(0.85),'),
        isTrue,
        reason: 'Indicator color must be AppTheme.primaryFixed.withOpacity(0.85)',
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Cân chỉnh góc bo vỏ ngoài thanh nav thành 28dp
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-03: Source Code Audit - Vỏ ngoài thanh nav có borderRadius 28dp, height 62dp, padding ngang 2dp', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Vỏ ngoài bo góc 28dp
      expect(
        shellContent.contains('borderRadius: BorderRadius.circular(28),'),
        isTrue,
        reason: 'Nav bar outer container must use BorderRadius.circular(28)',
      );

      // Chiều cao 62dp
      expect(
        shellContent.contains('height: 62,'),
        isTrue,
        reason: 'Nav bar outer container height must be 62dp',
      );

      // Padding horizontal 2dp
      expect(
        shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 2),'),
        isTrue,
        reason: 'Nav bar outer container padding must be EdgeInsets.symmetric(horizontal: 2)',
      );

      // Margin LTRB (16, 0, 16, 16)
      expect(
        shellContent.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),'),
        isTrue,
        reason: 'Nav bar outer container margin must be EdgeInsets.fromLTRB(16, 0, 16, 16)',
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Bảo toàn nền Solid White, lề 16dp và tương tác Tap-Only 120Hz
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-04: Source Code Audit - Nền 100% Solid White, viền hairline 0.8dp, multi-layer shadow, Tap-Only 220ms', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Nền solid white
      expect(shellContent.contains('color: Colors.white,'), isTrue,
          reason: 'Nav container must have solid Colors.white background');

      // Viền hairline 0.8dp
      expect(shellContent.contains('color: const Color(0xFFE2E8F0),'), isTrue);
      expect(shellContent.contains('width: 0.8,'), isTrue);

      // 2 tầng BoxShadow
      expect(shellContent.contains('color: Colors.black.withOpacity(0.08),'), isTrue);
      expect(shellContent.contains('blurRadius: 24,'), isTrue);
      expect(shellContent.contains('spreadRadius: -4,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 8),'), isTrue);

      expect(shellContent.contains('color: AppTheme.primary.withOpacity(0.04),'), isTrue);
      expect(shellContent.contains('blurRadius: 10,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 2),'), isTrue);

      // Tap-Only 220ms easeOutCubic
      expect(shellContent.contains('duration: const Duration(milliseconds: 220),'), isTrue);
      expect(shellContent.contains('curve: Curves.easeOutCubic,'), isTrue);

      // Không drag gesture
      expect(shellContent.contains('onPanUpdate'), isFalse);
      expect(shellContent.contains('onPanStart'), isFalse);
      expect(shellContent.contains('onPanEnd'), isFalse);

      // Bố cục _navItem: icon size 22, spacing 2, font Inter 10
      expect(shellContent.contains('size: 22,'), isTrue);
      expect(shellContent.contains('const SizedBox(height: 2),'), isTrue);
      expect(shellContent.contains("fontFamily: 'Inter',"), isTrue);
      expect(shellContent.contains('fontSize: 10,'), isTrue);
      expect(shellContent.contains('active ? FontWeight.w700 : FontWeight.w500,'), isTrue);
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn Test Suite & Widget Test thực tế MainShell
    // ══════════════════════════════════════════════════════════════════════════
    testWidgets('AC-05: Widget Test - MainShell verifies geometry (28dp outer, 18dp inner, margin 2dp) & tab navigation', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      final provider = AppProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: MainShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 5 tab labels exist
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Lịch học'), findsWidgets);
      expect(find.text('Điểm số'), findsWidgets);
      expect(find.text('Học phí'), findsWidgets);
      expect(find.text('Tài khoản'), findsWidgets);

      // Outer Nav Container verification
      final navContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == Colors.white &&
              deco.borderRadius == BorderRadius.circular(28) &&
              w.margin == const EdgeInsets.fromLTRB(16, 0, 16, 16) &&
              w.padding == const EdgeInsets.symmetric(horizontal: 2);
        }
        return false;
      });
      expect(navContainerFinder, findsOneWidget,
          reason: 'Nav outer container must have height 62, radius 28, margin (16,0,16,16), padding horizontal 2');

      // Active Indicator AnimatedPositioned verification
      final animatedPositionedFinder = find.byWidgetPredicate((w) {
        return w is AnimatedPositioned &&
            w.height == 48.0 &&
            w.top == 7.0 &&
            w.duration == const Duration(milliseconds: 220) &&
            w.curve == Curves.easeOutCubic;
      });
      expect(animatedPositionedFinder, findsOneWidget);

      // Inner Indicator Container verification
      final innerContainerFinder = find.descendant(
        of: animatedPositionedFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final deco = w.decoration as BoxDecoration;
            return deco.borderRadius == BorderRadius.circular(18) &&
                w.margin == const EdgeInsets.symmetric(horizontal: 2) &&
                deco.color == AppTheme.primaryFixed.withOpacity(0.85);
          }
          return false;
        }),
      );
      expect(innerContainerFinder, findsOneWidget,
          reason: 'Active indicator container must have margin horizontal 2 and borderRadius 18');

      // Test tab switching
      // Tap tab 1 (Lịch học)
      await tester.tap(find.text('Lịch học').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_1')), findsOneWidget);

      // Tap tab 2 (Điểm số)
      await tester.tap(find.text('Điểm số').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_2')), findsOneWidget);

      // Tap tab 3 (Học phí)
      await tester.tap(find.text('Học phí').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_3')), findsOneWidget);

      // Tap tab 4 (Tài khoản)
      await tester.tap(find.text('Tài khoản').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_4')), findsOneWidget);

      // Tap tab 0 (Tổng quan)
      await tester.tap(find.text('Tổng quan').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_0')), findsOneWidget);
    });
  });
}
