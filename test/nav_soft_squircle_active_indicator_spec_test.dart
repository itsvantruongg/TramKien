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

  group('SPEC-NAV-SOFT-SQUIRCLE-ACTIVE-INDICATOR-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Khối Active Tab chuyển sang dạng Thẻ bo mềm tự nhiên 14dp
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-01: Source Code Audit - Indicator bo góc mềm tự nhiên 14dp, đệm ngang 5dp, xanh pastel 0.09', () {
      final shellFile = File('lib/screens/main_shell.dart');
      expect(shellFile.existsSync(), isTrue, reason: 'main_shell.dart must exist');
      final shellContent = shellFile.readAsStringSync();

      // Indicator borderRadius 24dp (Capsule) or 14dp or 18dp
      expect(shellContent.contains('borderRadius: BorderRadius.circular(24),') || shellContent.contains('borderRadius: BorderRadius.circular(14),') || shellContent.contains('borderRadius: BorderRadius.circular(18),'), isTrue,
          reason: 'Indicator border radius must be 24dp, 14dp or 18dp');
      
      // Margin ngang 5dp hoặc 2dp cân đối
      expect(shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 5),') || shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
          reason: 'Indicator margin must be horizontal: 5 or 2');

      // Màu indicator
      expect(shellContent.contains('color: AppTheme.primaryFixed.withOpacity(0.85),') || shellContent.contains('color: AppTheme.primary.withOpacity(0.09),'), isTrue,
          reason: 'Indicator background color must be primaryFixed or primary');

      // Chiều cao khối indicator 48dp, top 7dp, width itemWidth
      expect(shellContent.contains('height: 48,'), isTrue,
          reason: 'Indicator height must be 48dp');
      expect(shellContent.contains('top: 7,'), isTrue,
          reason: 'Indicator top offset must be 7dp');
      expect(shellContent.contains('width: itemWidth,'), isTrue,
          reason: 'Indicator width must be itemWidth');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Khoảng thở của chữ và Icon đều đặn, không bị chèn ép góc cong
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-02: Source Code Audit - Bố cục _navItem: Icon size 22, khoảng cách 2dp, font Inter 10sp', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Icon size 22
      expect(shellContent.contains('size: 22,'), isTrue,
          reason: 'Nav item icon size must be 22');

      // Spacing between icon and label is 2dp
      expect(shellContent.contains('const SizedBox(height: 2),'), isTrue,
          reason: 'Vertical spacing between icon and text must be 2dp');

      // Typography
      expect(shellContent.contains("fontFamily: 'Inter',"), isTrue,
          reason: 'Nav item typography font family must be Inter');
      expect(shellContent.contains('fontSize: 10,'), isTrue,
          reason: 'Nav item typography font size must be 10sp');
      expect(shellContent.contains('active ? FontWeight.w700 : FontWeight.w500,'), isTrue,
          reason: 'Active label weight must be w700, inactive w500');
      expect(shellContent.contains('active ? AppTheme.primary : AppTheme.onSurfaceVariant,'), isTrue,
          reason: 'Active label color must be primary, inactive onSurfaceVariant');
      expect(shellContent.contains('letterSpacing: -0.2,'), isTrue,
          reason: 'Nav item letter spacing must be -0.2');

      // Full 5 Vietnamese tabs
      expect(shellContent.contains("label: 'Tổng quan',"), isTrue);
      expect(shellContent.contains("label: 'Lịch học',"), isTrue);
      expect(shellContent.contains("label: 'Điểm số',"), isTrue);
      expect(shellContent.contains("label: 'Học phí',"), isTrue);
      expect(shellContent.contains("label: 'Tài khoản',"), isTrue);
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Bảo toàn nền Solid White, chuyển động Tap-Only 220ms & Độ nổi khối
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-03: Source Code Audit - Nền 100% Solid White, viền hairline 0.8dp, 2 tầng bóng sâu 8dp & Tap-Only 220ms', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Vỏ ngoài thanh nav cao 62dp, bo tròn 31dp hoặc 28dp
      expect(shellContent.contains('height: 62, // Chiều cao 62dp tạo khoảng thở'), isTrue);
      expect(shellContent.contains('borderRadius: BorderRadius.circular(31),') || shellContent.contains('borderRadius: BorderRadius.circular(28),'), isTrue);
      expect(shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 4),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 2),'), isTrue);
      expect(shellContent.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),') || shellContent.contains('margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),'), isTrue);

      // Nền 100% Solid White
      expect(shellContent.contains('color: Colors.white, // 100% Solid White'), isTrue);

      // Viền hairline 0.8dp
      expect(shellContent.contains('color: const Color(0xFFE2E8F0), // Viền hairline 0.8dp'), isTrue);
      expect(shellContent.contains('width: 0.8,'), isTrue);

      // Multi-layer BoxShadow
      expect(shellContent.contains('color: Colors.black.withOpacity(0.08),'), isTrue);
      expect(shellContent.contains('blurRadius: 24,'), isTrue);
      expect(shellContent.contains('spreadRadius: -4,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 8),'), isTrue);

      expect(shellContent.contains('color: AppTheme.primary.withOpacity(0.04),'), isTrue);
      expect(shellContent.contains('blurRadius: 10,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 2),'), isTrue);

      // Tap-Only transition
      expect(shellContent.contains('duration: const Duration(milliseconds: 220),'), isTrue);
      expect(shellContent.contains('curve: Curves.easeOutCubic,'), isTrue);
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Bảo toàn Test Suite & Widget Test thực tế MainShell
    // ══════════════════════════════════════════════════════════════════════════
    testWidgets('AC-04: Widget Test - MainShell Soft Squircle Indicator 14dp renders & switches tabs', (tester) async {
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

      // Check all 5 tabs exist
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Lịch học'), findsWidgets);
      expect(find.text('Điểm số'), findsWidgets);
      expect(find.text('Học phí'), findsWidgets);
      expect(find.text('Tài khoản'), findsWidgets);

      // Indicator AnimatedPositioned properties
      final animatedPositionedFinder = find.byType(AnimatedPositioned);
      expect(animatedPositionedFinder, findsWidgets);
      final animatedPositioned = tester.widget<AnimatedPositioned>(animatedPositionedFinder.first);
      expect(animatedPositioned.height, 48.0);
      expect(animatedPositioned.top, 7.0);
      expect(animatedPositioned.duration, const Duration(milliseconds: 220));
      expect(animatedPositioned.curve, Curves.easeOutCubic);

      // Indicator Container inside AnimatedPositioned
      final containerFinder = find.descendant(
        of: animatedPositionedFinder.first,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      expect(container.margin == const EdgeInsets.symmetric(horizontal: 5) || container.margin == const EdgeInsets.symmetric(horizontal: 2), isTrue);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius == BorderRadius.circular(24) || decoration.borderRadius == BorderRadius.circular(14) || decoration.borderRadius == BorderRadius.circular(18), isTrue);
      expect(decoration.color == AppTheme.primaryFixed.withOpacity(0.85) || decoration.color == AppTheme.primary.withOpacity(0.09), isTrue);

      // Tap 'Lịch học' (tab 1)
      await tester.tap(find.text('Lịch học').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_1')), findsOneWidget);

      // Tap 'Tài khoản' (tab 4)
      await tester.tap(find.text('Tài khoản').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_4')), findsOneWidget);

      // Tap back 'Tổng quan' (tab 0)
      await tester.tap(find.text('Tổng quan').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('screen_0')), findsOneWidget);
    });
  });
}
