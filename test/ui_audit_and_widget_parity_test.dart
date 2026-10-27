import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  group('SPEC-UI-AUDIT-WIDGET-PARITY-01 Acceptance Criteria Verification Tests', () {
    test('AC-01 (iOS App Group & Entitlements): Runner.entitlements contains group.vn.edu.hau.tramkien', () {
      final file = File('ios/Runner/Runner.entitlements');
      expect(file.existsSync(), isTrue, reason: 'ios/Runner/Runner.entitlements must exist');
      final content = file.readAsStringSync();

      expect(content.contains('<key>com.apple.security.application-groups</key>'), isTrue,
          reason: 'Must declare com.apple.security.application-groups entitlement');
      expect(content.contains('<string>group.vn.edu.hau.tramkien</string>'), isTrue,
          reason: 'Must include group.vn.edu.hau.tramkien App Group');
    });

    test('AC-02 (iOS AppDelegate MethodChannel & WidgetCenter): AppDelegate.swift handles com.tramkien.hau/widget and updateWidget', () {
      final file = File('ios/Runner/AppDelegate.swift');
      expect(file.existsSync(), isTrue, reason: 'ios/Runner/AppDelegate.swift must exist');
      final content = file.readAsStringSync();

      expect(content.contains('import WidgetKit'), isTrue,
          reason: 'Must import WidgetKit');
      expect(content.contains('"com.tramkien.hau/widget"'), isTrue,
          reason: 'Must register MethodChannel com.tramkien.hau/widget');
      expect(content.contains('"updateWidget"'), isTrue,
          reason: 'Must handle updateWidget call');
      expect(content.contains('WidgetCenter.shared.reloadAllTimelines()'), isTrue,
          reason: 'Must trigger WidgetCenter.shared.reloadAllTimelines()');
      expect(content.contains('group.vn.edu.hau.tramkien'), isTrue,
          reason: 'Must synchronize shared UserDefaults for App Group group.vn.edu.hau.tramkien');
    });

    test('AC-03 (iOS WidgetKit Native Implementation): ScheduleWidgetKit.swift reads UserDefaults and supports all 4 form factors with zero AI filler', () {
      final file = File('ios/Runner/ScheduleWidgetKit.swift');
      expect(file.existsSync(), isTrue, reason: 'ios/Runner/ScheduleWidgetKit.swift must exist');
      final content = file.readAsStringSync();

      expect(content.contains('UserDefaults(suiteName: "group.vn.edu.hau.tramkien")') ||
             content.contains('UserDefaults(suiteName: appGroupId)'), isTrue,
          reason: 'Must read data from UserDefaults App Group suite');
      expect(content.contains('.systemSmall'), isTrue,
          reason: 'Must support .systemSmall');
      expect(content.contains('.systemMedium'), isTrue,
          reason: 'Must support .systemMedium');
      expect(content.contains('.systemLarge'), isTrue,
          reason: 'Must support .systemLarge');
      expect(content.contains('.accessoryRectangular'), isTrue,
          reason: 'Must support .accessoryRectangular');
      expect(content.contains('DayGridCellView'), isTrue,
          reason: 'Must contain weekly grid day cell view');
      expect(content.contains('WeeklySummaryCellView'), isTrue,
          reason: 'Must contain weekly grid summary cell view');
      expect(content.contains('TẬN HƯỞNG NGÀY NGHỈ'), isFalse,
          reason: 'Must eliminate AI filler "TẬN HƯỞNG NGÀY NGHỈ"');
      expect(content.contains('Không có ca học'), isTrue,
          reason: 'Must display clean Vietnamese empty state "Không có ca học"');
    });

    test('AC-04 (Widget Studio Dead Code Elimination): widget_studio_screen.dart purges dead functions and variables', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/screens/widget_studio_screen.dart must exist');
      final content = file.readAsStringSync();

      expect(content.contains('_buildSingleDayContent'), isFalse,
          reason: 'Dead function _buildSingleDayContent must be deleted');
      expect(content.contains('_buildSevenDaysContent'), isFalse,
          reason: 'Dead function _buildSevenDaysContent must be deleted');
      expect(content.contains('_buildSubVariantChip'), isFalse,
          reason: 'Dead function _buildSubVariantChip must be deleted');
      expect(content.contains('_weeklySelectedDayIndex'), isFalse,
          reason: 'Unused variable _weeklySelectedDayIndex must be deleted');
    });

    test('AC-05 (Responsive Grid Cells in Studio): Grid cells do not hardcode width 165', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('width: 165'), isFalse,
          reason: 'Hardcoded width: 165 in grid day and summary cells must be removed');
      expect(content.contains('SizedBox(\n            width: 165'), isFalse,
          reason: 'SizedBox(width: 165) must be removed from grid cells');
    });

    test('AC-06 (BottomNav Localization Consistency): main_shell.dart uses 100% Vietnamese tab labels', () {
      final file = File('lib/screens/main_shell.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("label: 'Tổng quan'"), isTrue,
          reason: "Tab 0 must be labeled 'Tổng quan'");
      expect(content.contains("label: 'Lịch học'"), isTrue,
          reason: "Tab 1 must be labeled 'Lịch học'");
      expect(content.contains("label: 'Điểm số'"), isTrue,
          reason: "Tab 2 must be labeled 'Điểm số'");
      expect(content.contains("label: 'Học phí'"), isTrue,
          reason: "Tab 3 must be labeled 'Học phí'");
      expect(content.contains("label: 'Tài khoản'"), isTrue,
          reason: "Tab 4 must be labeled 'Tài khoản'");

      // Old labels must not be in bottom nav
      expect(content.contains("label: 'Dashboard'"), isFalse);
      expect(content.contains("label: 'Tài chính'"), isFalse);
      expect(content.contains("label: 'Profile'"), isFalse);
    });

    test('AC-07 (No UI Emojis & Swiss Minimalist): finance_screen.dart uses Icons.receipt_long_outlined without emoji', () {
      final file = File('lib/screens/finance_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('📄'), isFalse,
          reason: 'Receipt emoji 📄 must be completely removed');
      expect(content.contains('receipt_long_outlined'), isTrue,
          reason: 'Must use Icons.receipt_long_outlined for receipts');
    });

    test('AC-08 (Branding Consistency): login_screen.dart uses Trạm Kiến - HAU branding', () {
      final file = File('lib/screens/login_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Trạm Kiến - HAU'), isTrue,
          reason: "Must display branding 'Trạm Kiến - HAU'");
      expect(content.contains('Trợ Lý Học Tập HAU'), isFalse,
          reason: "Legacy phrase 'Trợ Lý Học Tập HAU' must be replaced");
    });

    test('AC-09 (Clean Shared Widgets & Grades Screen): SurfaceCard has 0.5dp hairline border and grades_screen has no draft comments or _GpaHeroCard', () {
      final sharedFile = File('lib/widgets/shared_widgets.dart');
      expect(sharedFile.existsSync(), isTrue);
      final sharedContent = sharedFile.readAsStringSync();

      expect(sharedContent.contains('AppTheme.outlineVariant.withOpacity(0.4)'), isTrue,
          reason: 'SurfaceCard must declare border with AppTheme.outlineVariant.withOpacity(0.4)');
      expect(sharedContent.contains('width: 0.5'), isTrue,
          reason: 'SurfaceCard must declare border width 0.5');

      final gradesFile = File('lib/screens/grades_screen.dart');
      expect(gradesFile.existsSync(), isTrue);
      final gradesContent = gradesFile.readAsStringSync();

      expect(gradesContent.contains('_GpaHeroCard'), isFalse,
          reason: '_GpaHeroCard must be completely removed from grades_screen.dart');
      expect(gradesContent.contains('// ── GPA Hero ──'), isFalse,
          reason: 'Draft GPA Hero comment block must be removed');
    });

    testWidgets('AC-09 (Widget Test): SurfaceCard renders with 0.5dp hairline border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SurfaceCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.widget<Container>(containerFinder.first);
      final decoration = containerWidget.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.border, isNotNull);
      final border = decoration.border as Border?;
      expect(border, isNotNull);
      expect(border!.top.width, equals(0.5));
    });
  });
}
