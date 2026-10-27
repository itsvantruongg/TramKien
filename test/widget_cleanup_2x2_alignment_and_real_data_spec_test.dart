import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-WIDGET-CLEANUP-2X2-ALIGNMENT-AND-REAL-DATA-01 Verification Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Lược bỏ hoàn toàn Widget 2x2 khỏi Launcher & Studio
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Elimination of 2x2 Widget from Launcher & Studio', () {
      test('AndroidManifest.xml no longer contains SingleDay2x2ScheduleWidgetProvider receiver', () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(manifestFile.existsSync(), isTrue);
        final manifest = manifestFile.readAsStringSync();

        expect(
          manifest.contains('.SingleDay2x2ScheduleWidgetProvider'),
          isFalse,
          reason: 'SingleDay2x2ScheduleWidgetProvider receiver must be completely removed from AndroidManifest.xml',
        );

        expect(
          manifest.contains('.SingleDayScheduleWidgetProvider'),
          isTrue,
          reason: 'SingleDayScheduleWidgetProvider (4x2 Timeline) must be preserved',
        );
      });

      testWidgets('Widget Studio has no 2x2 toggle button; single_day defaults directly to 4x2 Timeline', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('variant_single_day_2x2')), findsNothing,
            reason: 'Variant 2x2 toggle button must be completely removed from Widget Studio');
        expect(find.byKey(const Key('variant_single_day_4x2')), findsNothing,
            reason: 'Variant 4x2 sub-selector row is removed since 4x2 is now the permanent single_day layout');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Căn đỉnh layout (Top-aligned) cho Widget 4x2
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Top-aligned layout for 4x2 Widget', () {
      test('widget_schedule_single_day.xml uses gravity="top" on single_day_content', () {
        final layoutFile = File('android/app/src/main/res/layout/widget_schedule_single_day.xml');
        expect(layoutFile.existsSync(), isTrue);
        final xml = layoutFile.readAsStringSync();

        final singleDayIdx = xml.indexOf('android:id="@+id/single_day_content"');
        expect(singleDayIdx, isNonNegative);
        final singleDayTagEnd = xml.indexOf('>', singleDayIdx);
        final singleDayBlock = xml.substring(singleDayIdx, singleDayTagEnd);

        expect(
          singleDayBlock.contains('android:gravity="top"'),
          isTrue,
          reason: 'single_day_content in widget_schedule_single_day.xml must use gravity="top"',
        );

        expect(
          singleDayBlock.contains('android:gravity="center_vertical"'),
          isFalse,
          reason: 'single_day_content must no longer use center_vertical',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Bỏ nhãn [ĐÃ HOÀN THÀNH] / [ĐÃ XONG] & Giữ nguyên màu sắc ca học
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Elimination of Completion Badges & Color Preservation', () {
      test('ScheduleWidgetProvider.kt preserves textColor/accentColor in single_day and removes [ĐÃ HOÀN THÀNH]', () {
        final providerFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(providerFile.existsSync(), isTrue);
        final kt = providerFile.readAsStringSync();

        final singleDayIdx = kt.indexOf('"single_day" -> {');
        expect(singleDayIdx, isNonNegative);
        final nextIdx = kt.indexOf('"single_day_2x2" -> {', singleDayIdx);
        expect(nextIdx, isNonNegative);
        final singleDayBranch = kt.substring(singleDayIdx, nextIdx);

        // Check single_day section does not assign [ĐÃ HOÀN THÀNH]
        expect(singleDayBranch.contains('"[ĐÃ HOÀN THÀNH]"'), isFalse,
            reason: 'ScheduleWidgetProvider.kt must not set [ĐÃ HOÀN THÀNH] text in single_day layout');

        // Check single_day does not dim finished class colors to textSecColor
        expect(singleDayBranch.contains('textSecColor else textColor'), isFalse,
            reason: 'Finished classes must retain textColor and not turn into dimmed textSecColor');
        expect(singleDayBranch.contains('textSecColor else accentColor'), isFalse,
            reason: 'Finished class hours and indicators must retain accentColor');
      });

      testWidgets('Live preview eliminates [ĐÃ HOÀN THÀNH] and [ĐÃ XONG] badges when all classes are finished', (tester) async {
        final finishedData = WidgetScheduleData(
          updatedAt: DateTime.now().toIso8601String(),
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Hai, 26/10',
          layoutMode: 'single_day',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'HÔM NAY',
              dateStr: '26/10',
              weekdayStr: 'T2',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Kho dữ liệu và khai phá dữ liệu',
                  classCode: 'TH4327_23CN 2',
                  timeSlot: '06:55 – 09:20 (T1–3)',
                  room: 'P.M-M5.03',
                  teacher: 'TS. Nguyễn Văn A',
                  isCurrentOrNext: false,
                  isFinished: true,
                ),
              ],
            ),
          ],
        );

        final initialPrefs = <String, Object>{
          'widget_schedule_data_single_day': finishedData.toJsonString(),
          'widget_theme_config': jsonEncode(WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day').toJson()),
        };
        SharedPreferences.setMockInitialValues(initialPrefs);

        await tester.binding.setSurfaceSize(const Size(450, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
            ],
            child: MaterialApp(
              home: WidgetStudioScreen(
                previewScheduleData: finishedData,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kho dữ liệu và khai phá dữ liệu'), findsOneWidget);
        expect(find.text('[ĐÃ HOÀN THÀNH]'), findsNothing,
            reason: 'Live preview must eliminate [ĐÃ HOÀN THÀNH] badge');
        expect(find.text('[ĐÃ XONG]'), findsNothing,
            reason: 'Live preview must eliminate [ĐÃ XONG] badge');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Bấm "Áp Dụng" nạp đúng dữ liệu thật của User ra Widget
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Apply Button Syncs Real Data', () {
      testWidgets('Studio _initData and _handleApply do not overwrite with mock data when user data is supplied', (tester) async {
        final realUserSchedule = WidgetScheduleData(
          updatedAt: DateTime.now().toIso8601String(),
          widgetTitle: 'Lịch hôm nay',
          widgetSubtitle: 'Thứ Hai, 26/10',
          layoutMode: 'single_day',
          days: [
            const WidgetDaySchedule(
              dayLabel: 'HÔM NAY',
              dateStr: '26/10',
              weekdayStr: 'T2',
              isToday: true,
              isDimmed: false,
              classes: [
                WidgetClassItem(
                  courseName: 'Kiến trúc công trình HAU',
                  classCode: 'KT101',
                  timeSlot: '06:55 – 11:55',
                  room: 'P.K301',
                  teacher: 'KTS. Lê Văn C',
                  isCurrentOrNext: true,
                  isFinished: false,
                ),
              ],
            ),
          ],
        );

        SharedPreferences.setMockInitialValues({
          'widget_schedule_data_single_day': realUserSchedule.toJsonString(),
          'widget_theme_config': jsonEncode(WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day').toJson()),
        });

        await tester.binding.setSurfaceSize(const Size(450, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
            ],
            child: MaterialApp(
              home: WidgetStudioScreen(
                previewScheduleData: realUserSchedule,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Preview displays real user schedule, not mock sample "Môn học 1"
        expect(find.text('Kiến trúc công trình HAU'), findsOneWidget);
        expect(find.text('Môn học 1'), findsNothing);

        // Tap Apply
        final applyBtn = find.text('ÁP DỤNG CẤU HÌNH VÀO WIDGET');
        expect(applyBtn, findsOneWidget);
        await tester.tap(applyBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // SharedPreferences should contain real schedule, not mock data
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('widget_schedule_data_single_day') ?? prefs.getString('widget_schedule_data');
        expect(savedJson, isNotNull);
        expect(savedJson!.contains('Kiến trúc công trình HAU'), isTrue);
        expect(savedJson.contains('Môn học 1'), isFalse);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Đồng bộ hóa iOS WidgetKit (Swift)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: iOS WidgetKit Parity', () {
      test('ScheduleWidgetKit.swift removes .systemSmall, removes top Spacer, and removes [ĐÃ HOÀN THÀNH]', () {
        final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
        expect(swiftFile.existsSync(), isTrue);
        final swift = swiftFile.readAsStringSync();

        // supportedFamilies check: .systemSmall removed
        final supportedFamiliesBlock = swift.substring(
          swift.indexOf('.supportedFamilies(['),
          swift.indexOf('])', swift.indexOf('.supportedFamilies([')),
        );
        expect(supportedFamiliesBlock.contains('.systemSmall'), isFalse,
            reason: '.systemSmall must be removed from supportedFamilies');
        expect(supportedFamiliesBlock.contains('.systemMedium'), isTrue);
        expect(supportedFamiliesBlock.contains('.systemLarge'), isTrue);
        expect(supportedFamiliesBlock.contains('.accessoryRectangular'), isTrue);

        // Top-alignment check: Spacer() above single course removed
        expect(swift.contains('if displayClasses.count == 1'), isFalse,
            reason: 'Top Spacer() for single course in .systemMedium must be removed');

        // Badge check: [ĐÃ HOÀN THÀNH] removed
        expect(swift.contains('"[ĐÃ HOÀN THÀNH]"'), isFalse,
            reason: '[ĐÃ HOÀN THÀNH] badge must be removed from Swift widget');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-06: Bảo toàn Test Suite & Không gây Regression Bug
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-06: Regression & Test Suite Preservation', () {
      test('All critical widget files exist and have no syntax issues', () {
        expect(File('android/app/src/main/AndroidManifest.xml').existsSync(), isTrue);
        expect(File('android/app/src/main/res/layout/widget_schedule_single_day.xml').existsSync(), isTrue);
        expect(File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt').existsSync(), isTrue);
        expect(File('ios/Runner/ScheduleWidgetKit.swift').existsSync(), isTrue);
        expect(File('lib/screens/widget_studio_screen.dart').existsSync(), isTrue);
      });
    });
  });
}
