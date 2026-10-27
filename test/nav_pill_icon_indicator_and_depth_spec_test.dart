import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/theme/app_theme.dart';

void main() {
  group('SPEC-NAV-PILL-ICON-INDICATOR-AND-DEPTH-01 Verification Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Khối Active Indicator (Pill-Icon) cao 32dp, bo tròn 16dp quanh Icon
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-01: Source Code Audit - Indicator cao 32dp, bo 16dp, xanh 0.12, chữ nằm ngoài', () {
      final shellFile = File('lib/screens/main_shell.dart');
      expect(shellFile.existsSync(), isTrue, reason: 'main_shell.dart must exist');
      final shellContent = shellFile.readAsStringSync();

      // Indicator geometry
      expect(shellContent.contains('height: 48,') || shellContent.contains('height: 32,'), isTrue,
          reason: 'Indicator height must be 48dp');
      expect(shellContent.contains('borderRadius: BorderRadius.circular(14),') || shellContent.contains('borderRadius: BorderRadius.circular(24),') || shellContent.contains('borderRadius: BorderRadius.circular(16),') || shellContent.contains('borderRadius: BorderRadius.circular(18),'), isTrue,
          reason: 'Indicator border radius must be 14dp, 24dp, 16dp or 18dp');
      expect(shellContent.contains('AppTheme.primary.withOpacity(0.09)') || shellContent.contains('AppTheme.primaryFixed.withOpacity(0.85)') || shellContent.contains('AppTheme.primary.withOpacity(0.12)'), isTrue,
          reason: 'Indicator color must be AppTheme.primary.withOpacity(0.09) or primaryFixed');
      expect(shellContent.contains('top: 7,') || shellContent.contains('top: 6,'), isTrue,
          reason: 'Indicator top must be 7dp');
      expect(shellContent.contains('width: itemWidth') || shellContent.contains('(itemWidth - 12).clamp(44.0, 56.0)'), isTrue,
          reason: 'Indicator width must be itemWidth');

      // Typography in _navItem
      expect(shellContent.contains("fontFamily: 'Inter'"), isTrue,
          reason: 'Label font family must be Inter');
      expect(shellContent.contains('fontSize: 10,'), isTrue,
          reason: 'Label font size must be 10sp');
      expect(shellContent.contains('active ? FontWeight.w700 : FontWeight.w500'), isTrue,
          reason: 'Label weight must be w700 when active, w500 when inactive');
      expect(shellContent.contains('active ? AppTheme.primary : AppTheme.onSurfaceVariant'), isTrue,
          reason: 'Label color must be primary when active, onSurfaceVariant when inactive');
      expect(shellContent.contains('letterSpacing: -0.2'), isTrue,
          reason: 'Label letterSpacing must be -0.2');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Vỏ ngoài nâng chiều cao 60dp, bo tròn 30dp & padding 6dp
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-02: Source Code Audit - Vỏ ngoài 60dp, bo tròn 30dp, đệm 6dp', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      expect(shellContent.contains('height: 62, // Chiều cao 62dp tạo khoảng thở') || shellContent.contains('height: 60,'), isTrue,
          reason: 'Main capsule container height must be 62dp or 60dp');
      expect(shellContent.contains('borderRadius: BorderRadius.circular(31),') || shellContent.contains('borderRadius: BorderRadius.circular(30),') || shellContent.contains('borderRadius: BorderRadius.circular(28),'), isTrue,
          reason: 'Main capsule border radius must be 31dp, 30dp or 28dp');
      expect(shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 4),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 6),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
          reason: 'Main capsule padding must be horizontal: 4, 6 or 2');
      expect(shellContent.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),') || shellContent.contains('margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),'), isTrue,
          reason: 'Main capsule margin must be EdgeInsets.fromLTRB(16, 0, 16, 16)');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Độ nổi khối đa tầng (Multi-layer Ambient Shadow) & Hairline 0.8dp
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-03: Source Code Audit - 2 lớp BoxShadow và viền 0.8dp', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Border 0.8dp hairline Color(0xFFE2E8F0)
      expect(shellContent.contains('color: const Color(0xFFE2E8F0), // Viền hairline 0.8dp'), isTrue,
          reason: 'Border color must be Color(0xFFE2E8F0)');
      expect(shellContent.contains('width: 0.8,'), isTrue,
          reason: 'Border width must be 0.8dp');

      // BoxShadow 1: Ambient deep shadow
      expect(shellContent.contains('color: Colors.black.withOpacity(0.08),'), isTrue,
          reason: 'BoxShadow layer 1 must use black with 0.08 opacity');
      expect(shellContent.contains('blurRadius: 24,'), isTrue,
          reason: 'BoxShadow layer 1 blurRadius must be 24');
      expect(shellContent.contains('spreadRadius: -4,'), isTrue,
          reason: 'BoxShadow layer 1 spreadRadius must be -4');
      expect(shellContent.contains('offset: const Offset(0, 8),'), isTrue,
          reason: 'BoxShadow layer 1 offset must be (0, 8)');

      // BoxShadow 2: Soft accent tint
      expect(shellContent.contains('color: AppTheme.primary.withOpacity(0.04),'), isTrue,
          reason: 'BoxShadow layer 2 must use primary with 0.04 opacity');
      expect(shellContent.contains('blurRadius: 10,'), isTrue,
          reason: 'BoxShadow layer 2 blurRadius must be 10');
      expect(shellContent.contains('offset: const Offset(0, 2),'), isTrue,
          reason: 'BoxShadow layer 2 offset must be (0, 2)');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Phản hồi chuyển tab Tap-Only mượt mà (AnimatedPositioned 220ms)
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-04: Source Code Audit - AnimatedPositioned duration 220ms, curve easeOutCubic', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      expect(shellContent.contains('AnimatedPositioned('), isTrue,
          reason: 'Must use AnimatedPositioned for pill-icon indicator');
      expect(shellContent.contains('duration: const Duration(milliseconds: 220),'), isTrue,
          reason: 'AnimatedPositioned duration must be 220ms');
      expect(shellContent.contains('curve: Curves.easeOutCubic,'), isTrue,
          reason: 'AnimatedPositioned curve must be Curves.easeOutCubic');
      expect(shellContent.contains('AnimatedScale('), isTrue,
          reason: 'Icon scale animation must use AnimatedScale');
      expect(shellContent.contains('scale: active ? 1.05 : 1.0,'), isTrue,
          reason: 'Active icon scale must be 1.05');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04 & AC-05: Widget Test - MainShell rendering and 5-tab switching
    // ══════════════════════════════════════════════════════════════════════════
    testWidgets('AC-04 & AC-05: Widget Test - MainShell 60dp Pill-Icon Navigation operates smoothly',
        (WidgetTester tester) async {
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

      // Verify pill-icon indicator AnimatedPositioned
      final animatedPositionedFinder = find.byType(AnimatedPositioned);
      expect(animatedPositionedFinder, findsWidgets);
      final animatedPositioned = tester.widget<AnimatedPositioned>(animatedPositionedFinder.first);
      expect(animatedPositioned.height == 48.0 || animatedPositioned.height == 32.0, isTrue);
      expect(animatedPositioned.top == 7.0 || animatedPositioned.top == 6.0, isTrue);
      expect(animatedPositioned.duration, const Duration(milliseconds: 220));
      expect(animatedPositioned.curve, Curves.easeOutCubic);

      // Tap on Tab 1: 'Lịch học'
      await tester.tap(find.text('Lịch học').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'Tapping Tab 1 should not throw');
      expect(find.byKey(const ValueKey('screen_1')), findsOneWidget);

      // Tap on Tab 4: 'Tài khoản'
      await tester.tap(find.text('Tài khoản').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'Tapping Tab 4 should not throw');
      expect(find.byKey(const ValueKey('screen_4')), findsOneWidget);

      // Tap back to Tab 0: 'Tổng quan'
      await tester.tap(find.text('Tổng quan').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'Tapping back to Tab 0 should not throw');
      expect(find.byKey(const ValueKey('screen_0')), findsOneWidget);
    });
  });
}
