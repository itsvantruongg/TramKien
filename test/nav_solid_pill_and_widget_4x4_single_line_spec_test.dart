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

  group('SPEC-NAV-SOLID-PILL-AND-WIDGET-4X4-SINGLE-LINE-01 Acceptance Tests', () {
    test('AC-01: Khóa cứng 1 dòng tên môn trên Widget 4x4 Android', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue, reason: 'ScheduleWidgetProvider.kt must exist');
      final ktContent = ktFile.readAsStringSync();

      // Verify weeklyNameMaxLines is hardcoded to 1
      expect(ktContent.contains('val weeklyNameMaxLines = 1'), isTrue,
          reason: 'weeklyNameMaxLines must be hardcoded to 1');

      // Verify both nameIds and class2NameIds apply weeklyNameMaxLines
      expect(ktContent.contains('views.setInt(nameIds[i], "setMaxLines", weeklyNameMaxLines)'), isTrue,
          reason: 'nameIds must use weeklyNameMaxLines');
      expect(ktContent.contains('views.setInt(class2NameIds[i], "setMaxLines", weeklyNameMaxLines)'), isTrue,
          reason: 'class2NameIds must use weeklyNameMaxLines');
    });

    test('AC-02: Thanh điều hướng Solid Pill 56dp loại bỏ hoàn toàn Blur', () {
      final shellFile = File('lib/screens/main_shell.dart');
      expect(shellFile.existsSync(), isTrue, reason: 'main_shell.dart must exist');
      final shellContent = shellFile.readAsStringSync();

      // Verify BackdropFilter and ImageFilter are completely removed
      expect(shellContent.contains('BackdropFilter'), isFalse,
          reason: 'main_shell.dart must eliminate BackdropFilter');
      expect(shellContent.contains('ImageFilter'), isFalse,
          reason: 'main_shell.dart must eliminate ImageFilter');
      expect(shellContent.contains("import 'dart:ui';"), isFalse,
          reason: 'dart:ui import must be removed');

      // Verify Solid Pill Container specs
      expect(shellContent.contains('height: 62,') || shellContent.contains('height: 60,'), isTrue,
          reason: 'Bottom bar height must be 62dp');
      expect(shellContent.contains('margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),') || shellContent.contains('margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),'), isTrue,
          reason: 'Margin must be EdgeInsets.fromLTRB(16, 0, 16, 16)');
      expect(shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 4),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 6),') || shellContent.contains('padding: const EdgeInsets.symmetric(horizontal: 2),'), isTrue,
          reason: 'Padding must be EdgeInsets.symmetric(horizontal: 4 or 2)');
      expect(shellContent.contains('color: Colors.white,'), isTrue,
          reason: 'Background color must be solid Colors.white');
      expect(shellContent.contains('borderRadius: BorderRadius.circular(31),') || shellContent.contains('borderRadius: BorderRadius.circular(30),') || shellContent.contains('borderRadius: BorderRadius.circular(28),'), isTrue,
          reason: 'Border radius must be 31, 30 or 28');
      expect(shellContent.contains('color: const Color(0xFFE2E8F0),'), isTrue,
          reason: 'Border color must be Color(0xFFE2E8F0)');
      expect(shellContent.contains('width: 0.8,'), isTrue,
          reason: 'Border width must be 0.8 hairline');

      // Verify Active Indicator specs
      expect(shellContent.contains('height: 48,') || shellContent.contains('height: 32,'), isTrue,
          reason: 'Active indicator height must be 48dp');
      expect(shellContent.contains('borderRadius: BorderRadius.circular(14),') || shellContent.contains('borderRadius: BorderRadius.circular(24),') || shellContent.contains('borderRadius: BorderRadius.circular(16),') || shellContent.contains('borderRadius: BorderRadius.circular(18),'), isTrue,
          reason: 'Active indicator border radius must be 14dp, 24dp, 16dp or 18dp');
      expect(shellContent.contains('AppTheme.primary.withOpacity(0.09)') || shellContent.contains('AppTheme.primaryFixed.withOpacity(0.85)') || shellContent.contains('AppTheme.primary.withOpacity(0.12)'), isTrue,
          reason: 'Active indicator color must use primary or primaryFixed');
    });

    test('AC-03: Tinh giản cơ chế chuyển Tab Tap-Only (Loại bỏ Drag)', () {
      final shellFile = File('lib/screens/main_shell.dart');
      final shellContent = shellFile.readAsStringSync();

      // Verify drag variables are removed
      expect(shellContent.contains('_navDragging'), isFalse,
          reason: '_navDragging must be removed');
      expect(shellContent.contains('_startDragDx'), isFalse,
          reason: '_startDragDx must be removed');
      expect(shellContent.contains('_navDragValue'), isFalse,
          reason: '_navDragValue must be removed');
      expect(shellContent.contains('_initialTapIdx'), isFalse,
          reason: '_initialTapIdx must be removed');

      // Verify drag methods are removed
      expect(shellContent.contains('_startNavDrag'), isFalse,
          reason: '_startNavDrag must be removed');
      expect(shellContent.contains('_updateNavDrag'), isFalse,
          reason: '_updateNavDrag must be removed');
      expect(shellContent.contains('_endNavDrag'), isFalse,
          reason: '_endNavDrag must be removed');
      expect(shellContent.contains('_cancelNavDrag'), isFalse,
          reason: '_cancelNavDrag must be removed');

      // Verify onPan handlers are removed
      expect(shellContent.contains('onPanDown'), isFalse,
          reason: 'onPanDown must be removed');
      expect(shellContent.contains('onPanUpdate'), isFalse,
          reason: 'onPanUpdate must be removed');
      expect(shellContent.contains('onPanEnd'), isFalse,
          reason: 'onPanEnd must be removed');

      // Verify AnimatedPositioned indicator motion
      expect(shellContent.contains('AnimatedPositioned('), isTrue,
          reason: 'Must use AnimatedPositioned for active indicator slide');
      expect(shellContent.contains('left: _idx * itemWidth'), isTrue,
          reason: 'Position must be bound to _idx * itemWidth');
      expect(shellContent.contains('top: 7,') || shellContent.contains('top: 6,'), isTrue,
          reason: 'Top must be 7dp');
      expect(shellContent.contains('duration: const Duration(milliseconds: 220),'), isTrue,
          reason: 'Indicator animation duration must be 220ms');
      expect(shellContent.contains('curve: Curves.easeOutCubic,'), isTrue,
          reason: 'Indicator animation curve must be Curves.easeOutCubic');
    });

    testWidgets('AC-04 & AC-05: Widget Test - MainShell tap navigation operates smoothly without errors',
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

      // Verify initial tab 0 ('Tổng quan') is rendered
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Lịch học'), findsWidgets);
      expect(find.text('Điểm số'), findsWidgets);
      expect(find.text('Học phí'), findsWidgets);
      expect(find.text('Tài khoản'), findsWidgets);

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
