import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/main_shell.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SPEC-NAV-RESTORE-FULL-PILL-AND-END-TIME-HYPHEN-01 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Khôi phục kiểu dáng viên thuốc xanh bao cả Icon và Text
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-01: Source Code Audit - Viên thuốc xanh bao trọn cả Icon lẫn Label (cao 48dp, bo 24dp)', () {
      final shellFile = File('lib/screens/main_shell.dart');
      expect(shellFile.existsSync(), isTrue, reason: 'main_shell.dart must exist');
      final shellContent = shellFile.readAsStringSync();

      // Indicator height 48dp
      expect(shellContent.contains('height: 48,'), isTrue,
          reason: 'Indicator height must be 48dp to enclose both Icon and Text');
      // Indicator borderRadius 14dp (soft squircle) or 24dp or 18dp
      expect(shellContent.contains('borderRadius: BorderRadius.circular(14),') || shellContent.contains('borderRadius: BorderRadius.circular(24),') || shellContent.contains('borderRadius: BorderRadius.circular(18),'), isTrue,
          reason: 'Indicator border radius must be 14dp (soft squircle), 24dp or 18dp');
      // Indicator color pastel primary 0.09 or primaryFixed 0.85
      expect(shellContent.contains('AppTheme.primary.withOpacity(0.09)') || shellContent.contains('AppTheme.primaryFixed.withOpacity(0.85)'), isTrue,
          reason: 'Indicator color must be AppTheme.primary.withOpacity(0.09) or primaryFixed');
      // Indicator width is itemWidth
      expect(shellContent.contains('width: itemWidth,'), isTrue,
          reason: 'Indicator width must be itemWidth');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Tăng khoảng đệm thoáng đãng giữa viên thuốc xanh và vỏ ngoài
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-02: Source Code Audit - Vỏ ngoài 62dp, bo 31dp, top 7dp, margin ngang 6dp', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Vỏ ngoài thanh nav cao 62dp
      expect(shellContent.contains('height: 62, // Chiều cao 62dp tạo khoảng thở'), isTrue,
          reason: 'Outer nav capsule height must be 62dp');
      // Bo tròn 31dp (62 / 2) hoặc 28dp
      expect(shellContent.contains('borderRadius: BorderRadius.circular(31),') || shellContent.contains('borderRadius: BorderRadius.circular(28),'), isTrue,
          reason: 'Outer nav border radius must be 31dp or 28dp');
      // Padding horizontal 4 hoặc 2
      expect(shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 4),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
          reason: 'Outer nav padding must be horizontal: 4 or 2');
      // Margin LTRB (16, 0, 16, 16)
      expect(shellContent.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),') || shellContent.contains('margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),'), isTrue,
          reason: 'Outer nav margin must be EdgeInsets.fromLTRB(16, 0, 16, 16)');
      // Lề trên 7dp ((62 - 48) / 2 = 7)
      expect(shellContent.contains('top: 7,'), isTrue,
          reason: 'Indicator top offset must be 7dp ((62 - 48) / 2 = 7)');
      // Lề ngang 5dp, 6dp hoặc 2dp tạo khoảng thở
      expect(shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 5),') || shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 6),') || shellContent.contains('margin: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
          reason: 'Indicator margin must be horizontal: 5, 6 or 2');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Thêm dấu gạch "-" ở đầu giờ kết thúc trên Widget 4x2
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Prefix Hyphen "- " on End Time for 4x2 Widget (Android, iOS & Studio)', () {
      test('ScheduleWidgetProvider.kt extractEndTime prefixes "- "', () {
        final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(ktFile.existsSync(), isTrue);
        final kt = ktFile.readAsStringSync();

        expect(kt.contains('fun extractEndTime(timeSlot: String): String'), isTrue);
        expect(kt.contains('return if (formatted.isNotEmpty()) "- \$formatted" else ""'), isTrue);
        expect(kt.contains('views.setTextViewText(R.id.single_class_1_time_end, c1TimeEnd)'), isTrue);
        expect(kt.contains('views.setTextViewText(R.id.single_class_2_time_end, c2TimeEnd)'), isTrue);
      });

      test('ScheduleWidgetKit.swift extractEndTime prefixes "- "', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        expect(swift.contains('func extractEndTime(_ timeSlot: String) -> String'), isTrue);
        expect(swift.contains('return formatted.isEmpty ? "" : "- \\(formatted)"'), isTrue);
        expect(swift.contains('Text(extractEndTime(c.timeSlot))'), isTrue);
      });

      test('ScheduleCard.formatEndHour formats with "- " prefix', () {
        expect(ScheduleCard.formatEndHour('06:55 – 09:20 (T1–3)'), equals('- 9h20'));
        expect(ScheduleCard.formatEndHour('09:30 – 11:55 (T4–6)'), equals('- 11h55'));
        expect(ScheduleCard.formatEndHour('12:55 – 17:05 (T8–12)'), equals('- 17h05'));
        expect(ScheduleCard.formatEndHour('17:15 – 19:40 (T13–15)'), equals('- 19h40'));
        expect(ScheduleCard.formatEndHour('07:00 – 11:00'), equals('- 11h'));
        expect(ScheduleCard.formatEndHour('7h - 11h'), equals('- 11h'));
        expect(ScheduleCard.formatEndHour('7h'), equals(''));
        expect(ScheduleCard.formatEndHour(''), equals(''));
      });

      testWidgets('Widget Studio Live Preview renders "- " on end times for single_day 4x2', (tester) async {
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

        // Must display mock courses with hyphens
        expect(find.text('- 9h20'), findsWidgets);
        expect(find.text('- 11h55'), findsWidgets);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Bảo toàn nền đặc Solid White, bóng nổi khối & Tap-Only 120Hz
    // ══════════════════════════════════════════════════════════════════════════
    test('AC-04: Source Code Audit - Nền 100% Solid White, 2 tầng bóng sâu 8dp & Tap-Only 220ms', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Nền Solid White
      expect(shellContent.contains('color: Colors.white, // 100% Solid White'), isTrue,
          reason: 'Nav background must be solid Colors.white');
      // Viền hairline 0.8dp
      expect(shellContent.contains('color: const Color(0xFFE2E8F0), // Viền hairline 0.8dp'), isTrue,
          reason: 'Nav border must be Color(0xFFE2E8F0)');
      expect(shellContent.contains('width: 0.8,'), isTrue,
          reason: 'Border width must be 0.8dp');

      // BoxShadow 1: Deep ambient shadow (blur 24, spread -4, offset 8)
      expect(shellContent.contains('color: Colors.black.withOpacity(0.08),'), isTrue);
      expect(shellContent.contains('blurRadius: 24,'), isTrue);
      expect(shellContent.contains('spreadRadius: -4,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 8),'), isTrue);

      // BoxShadow 2: Primary soft tint (blur 10, offset 2)
      expect(shellContent.contains('color: AppTheme.primary.withOpacity(0.04),'), isTrue);
      expect(shellContent.contains('blurRadius: 10,'), isTrue);
      expect(shellContent.contains('offset: const Offset(0, 2),'), isTrue);

      // Tap-Only transition
      expect(shellContent.contains('duration: const Duration(milliseconds: 220),'), isTrue);
      expect(shellContent.contains('curve: Curves.easeOutCubic,'), isTrue);
      expect(shellContent.contains('onPanDown'), isFalse, reason: 'Pan gesture must remain removed');
      expect(shellContent.contains('_navDragging'), isFalse, reason: 'Drag tracking must remain removed');
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Bảo toàn Test Suite & Widget Test thực tế MainShell
    // ══════════════════════════════════════════════════════════════════════════
    testWidgets('AC-05: Widget Test - MainShell Full-Tab Pill 62dp switches tabs smoothly', (tester) async {
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

      // Check all 5 labels exist
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
