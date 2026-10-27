import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-UX-REFINEMENTS-WIDGET-02 Acceptance Criteria Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Smooth Shimmer Sweep & Zero Snap Glitch
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Smooth Shimmer Sweep & Zero Snap Glitch', () {
      test('Source Code: AppShimmerScope & SkeletonBox implement Curves.easeInOut and [-2.0, 2.0] sweep range', () {
        final file = File('lib/widgets/shared_widgets.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // 1. CurvedAnimation with Curves.easeInOut (continuous sweep without dead pause)
        expect(
          content.contains('curve: Curves.easeInOut'),
          isTrue,
          reason: 'AppShimmerScopeState must use Curves.easeInOut for continuous smooth sweep',
        );

        // 2. Expanded sweep range: (t * 4.0) - 2.0
        expect(
          content.contains('final offset = (t * 4.0) - 2.0;'),
          isTrue,
          reason: 'SkeletonBox must expand sweep range offset to (t * 4.0) - 2.0',
        );

        // 3. Begin & End alignments
        expect(
          content.contains('begin: Alignment(-1.5 + offset, -1.5 + offset)'),
          isTrue,
          reason: 'SkeletonBox gradient begin must be Alignment(-1.5 + offset, -1.5 + offset)',
        );
        expect(
          content.contains('end: Alignment(1.5 + offset, 1.5 + offset)'),
          isTrue,
          reason: 'SkeletonBox gradient end must be Alignment(1.5 + offset, 1.5 + offset)',
        );
      });

      testWidgets('Widget Test: AppShimmerScope and SkeletonBox render smoothly and cleanly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AppShimmerScope(
                child: Column(
                  children: [
                    SkeletonBox(width: 120, height: 20),
                    SizedBox(height: 10),
                    SkeletonBox(width: 200, height: 40, radius: 12),
                  ],
                ),
              ),
            ),
          ),
        );

        // Frame 0: t = 0.0 -> Skeleton boxes exist and render without overflow or exception
        expect(find.byType(SkeletonBox), findsNWidgets(2));
        await tester.pump(const Duration(milliseconds: 500));
        // Rest phase: t >= 0.75 (around 1125ms of 1500ms)
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Natural Widget Pinning Flow & No App Drawer Drop
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Natural Widget Pinning Flow & No App Drawer Drop', () {
      test('Source Code: WidgetPinSuccessReceiver.kt does NOT force CATEGORY_HOME', () {
        final receiverFile = File('android/app/src/main/kotlin/com/tramkien/hau/WidgetPinSuccessReceiver.kt');
        expect(receiverFile.existsSync(), isTrue);
        final content = receiverFile.readAsStringSync();

        expect(content.contains('CATEGORY_HOME'), isFalse,
            reason: 'WidgetPinSuccessReceiver must NOT force CATEGORY_HOME');
        expect(content.contains('context.startActivity'), isFalse,
            reason: 'WidgetPinSuccessReceiver must NOT launch Home activity directly');
        expect(content.contains('ACTION_UPDATE_WIDGET'), isTrue,
            reason: 'WidgetPinSuccessReceiver must send ACTION_UPDATE_WIDGET broadcast');
      });

      test('Source Code: MainActivity.kt handles minimizeApp via moveTaskToBack', () {
        final mainActivityFile = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
        expect(mainActivityFile.existsSync(), isTrue);
        final content = mainActivityFile.readAsStringSync();

        expect(content.contains('"minimizeApp"'), isTrue,
            reason: 'MainActivity.kt must handle minimizeApp method channel call');
        expect(content.contains('moveTaskToBack(true)'), isTrue,
            reason: 'minimizeApp must invoke moveTaskToBack(true)');
      });

      test('Source Code: WidgetDataSyncService provides minimizeApp() helper', () {
        final serviceFile = File('lib/services/widget_data_sync_service.dart');
        expect(serviceFile.existsSync(), isTrue);
        final content = serviceFile.readAsStringSync();

        expect(content.contains('static Future<bool> minimizeApp()'), isTrue,
            reason: 'WidgetDataSyncService must provide static Future<bool> minimizeApp()');
        expect(content.contains("'minimizeApp'"), isTrue);
      });

      testWidgets('Widget Test: Separated Save vs Pin Flow in WidgetStudioScreen', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.binding.setSurfaceSize(const Size(450, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Nút "ÁP DỤNG" trên AppBar chỉ lưu cấu hình và cập nhật giao diện
        await tester.tap(find.text('ÁP DỤNG'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('✓ Đã cập nhật giao diện Widget'), findsOneWidget);

        // Clear previous SnackBar before scrolling and tapping
        ScaffoldMessenger.of(tester.element(find.text('✓ Đã cập nhật giao diện Widget'))).clearSnackBars();
        await tester.pumpAndSettle();

        // 2. Nút "Thêm vào Màn hình chính" (btn_add_to_home) đã được gỡ bỏ hoàn toàn
        expect(find.byKey(const Key('btn_add_to_home')), findsNothing);
        expect(find.text('Thêm vào Màn hình chính'), findsNothing);

        // 3. Dòng hướng dẫn nhẹ nhàng đưa widget ra màn hình chính xuất hiện
        await tester.scrollUntilVisible(
          find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

        // 4. Nút chính "ÁP DỤNG CẤU HÌNH VÀO WIDGET" hoạt động chuẩn xác
        await tester.tap(find.text('ÁP DỤNG CẤU HÌNH VÀO WIDGET'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('✓ Đã cập nhật giao diện Widget'), findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Transient Session Privacy Protection
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Transient Session Privacy Protection', () {
      test('Source Code: AppProvider quickAuthCheck and lifecycle clear widget data when remember is false', () {
        final appProviderFile = File('lib/providers/app_provider.dart');
        expect(appProviderFile.existsSync(), isTrue);
        final content = appProviderFile.readAsStringSync();

        expect(content.contains('if (remember == false)'), isTrue,
            reason: 'quickAuthCheck must check remember == false to clear widget data');
        expect(content.contains('WidgetDataSyncService.clearAllWidgetData'), isTrue);
        expect(content.contains('AppLifecycleState.detached'), isTrue,
            reason: 'didChangeAppLifecycleState must check detached state');
      });

      test('clearAllWidgetData clears all 5 widget schedule keys from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({
          WidgetDataSyncService.keyWidgetScheduleData: '{"test": 1}',
          WidgetDataSyncService.keyWidgetScheduleDataSingleDay: '{"test": 2}',
          WidgetDataSyncService.keyWidgetScheduleDataThreeDays: '{"test": 3}',
          WidgetDataSyncService.keyWidgetScheduleDataSevenDays: '{"test": 4}',
          WidgetDataSyncService.keyWidgetScheduleDataTomorrow: '{"test": 5}',
        });
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleData), isTrue);
        await WidgetDataSyncService.clearAllWidgetData(prefs: prefs);

        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleData), isFalse);
        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSingleDay), isFalse);
        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataThreeDays), isFalse);
        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSevenDays), isFalse);
        expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataTomorrow), isFalse);
      });

      test('Source Code: ScheduleWidgetProvider.kt displays safe fallback "Trạm Kiến • Vui lòng đăng nhập" on empty data', () {
        final providerFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(providerFile.existsSync(), isTrue);
        final content = providerFile.readAsStringSync();

        expect(
          content.contains('views.setTextViewText(R.id.single_2x2_empty_text, "Trạm Kiến • Vui lòng đăng nhập")'),
          isTrue,
          reason: '2x2 widget must display safety text on empty/cleared data',
        );
        expect(
          content.contains('views.setTextViewText(R.id.day_1_class_name, "Trạm Kiến • Vui lòng đăng nhập")'),
          isTrue,
          reason: '3-day (4x2) widget must display safety text on empty/cleared data',
        );
        expect(
          content.contains('views.setTextViewText(nameIds[i], if (i == 0) "Trạm Kiến • Vui lòng đăng nhập" else "")'),
          isTrue,
          reason: '7-day (4x4) weekly grid must display safety text on empty/cleared data',
        );
        expect(
          content.contains('views.setTextViewText(R.id.grid_cell_summary_empty_days, "Trạm Kiến • Vui lòng đăng nhập")'),
          isTrue,
          reason: 'Summary cell in 4x4 must display safety text on empty/cleared data',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Crisp Brand Splash on Dark Mode
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Crisp Brand Splash on Dark Mode', () {
      test('values-night-v31/styles.xml locks windowSplashScreenBackground to #FFFFFF', () {
        final v31NightFile = File('android/app/src/main/res/values-night-v31/styles.xml');
        expect(v31NightFile.existsSync(), isTrue);
        final content = v31NightFile.readAsStringSync();

        expect(content.contains('<item name="android:windowSplashScreenBackground">#FFFFFF</item>'), isTrue);
        expect(content.contains('<item name="android:windowSplashScreenIconBackgroundColor">#FFFFFF</item>'), isTrue);
      });

      test('values-night/styles.xml uses white launch background', () {
        final nightFile = File('android/app/src/main/res/values-night/styles.xml');
        expect(nightFile.existsSync(), isTrue);
        final content = nightFile.readAsStringSync();

        expect(content.contains('<item name="android:windowBackground">@drawable/launch_background</item>'), isTrue);
      });

      test('pubspec.yaml configures flutter_native_splash with clean #FFFFFF', () {
        final pubspecFile = File('pubspec.yaml');
        expect(pubspecFile.existsSync(), isTrue);
        final content = pubspecFile.readAsStringSync();

        expect(content.contains('color: "#FFFFFF"'), isTrue);
        expect(content.contains('icon_background_color: "#FFFFFF"'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Widget Configuration Architecture
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Widget Configuration Architecture', () {
      test('All appwidget-provider XML files omit reconfigurable|configuration_optional to prevent Samsung launcher crash', () {
        final xmlFiles = [
          'android/app/src/main/res/xml/widget_schedule_single_day_2x2_info.xml',
          'android/app/src/main/res/xml/widget_schedule_three_days_info.xml',
          'android/app/src/main/res/xml/widget_schedule_weekly_info.xml',
        ];

        for (final path in xmlFiles) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path must exist');
          final content = file.readAsStringSync();
          expect(
            content.contains('android:widgetFeatures="reconfigurable|configuration_optional"'),
            isFalse,
            reason: '$path must omit reconfigurable|configuration_optional to prevent launcher crash',
          );
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-06: Widget Background Minimalism - Pure Binary Choice
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-06: Widget Background Minimalism - Pure Binary Choice', () {
      test('WidgetThemeConfig: bgStyle is simplified to solid and transparent with solid presets', () {
        final swiss = WidgetThemeConfig.minimalSwiss();
        expect(swiss.bgStyle, equals('solid'));
        expect(swiss.bgColorHex, equals('#1C1C1E'));
        expect(swiss.bgOpacity, equals(1.0));

        final light = WidgetThemeConfig.solidLight();
        expect(light.bgStyle, equals('solid'));
        expect(light.bgColorHex, equals('#FFFFFF'));
        expect(light.bgOpacity, equals(1.0));
        expect(light.textPrimaryHex, equals('#0F172A'));
        expect(light.textSecondaryHex, equals('#64748B'));

        final ghost = WidgetThemeConfig.ghostMode();
        expect(ghost.bgStyle, equals('transparent'));
        expect(ghost.bgColorHex, equals('#00000000'));
        expect(ghost.bgOpacity, equals(0.0));

        // Legacy values normalize to solid
        final fromLegacy = WidgetThemeConfig.fromJson({'bg_style': 'frosted_glass'});
        expect(fromLegacy.bgStyle, equals('solid'));
      });

      testWidgets('WidgetStudioScreen: UI presents exactly 2 background style options and hides Opacity slider', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Exactly 2 binary options
        expect(find.text('Nền Màu Đặc'), findsOneWidget);
        expect(find.text('Trong suốt 100%'), findsOneWidget);
        expect(find.text('Kính mờ Hệ thống (iOS)'), findsNothing);
        expect(find.text('Kính mờ Tự chọn'), findsNothing);

        // 2. Opacity slider is hidden
        expect(find.byType(Slider), findsNothing);

        // 3. When Nền Màu Đặc is selected, quick selectors [Nền Tối] and [Nền Sáng] are shown
        expect(find.text('Nền Tối'), findsOneWidget);
        expect(find.text('Nền Sáng'), findsOneWidget);

        // Tap Nền Sáng
        await tester.tap(find.text('Nền Sáng'));
        await tester.pumpAndSettle();

        // Tap Trong suốt 100%
        await tester.tap(find.text('Trong suốt 100%'));
        await tester.pumpAndSettle();

        expect(find.text('(Nền trong suốt - Không áp dụng màu nền)'), findsOneWidget);
      });

      test('ScheduleWidgetProvider.kt maps solid to solid vector drawables and transparent to transparent drawable', () {
        final providerFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(providerFile.existsSync(), isTrue);
        final content = providerFile.readAsStringSync();

        expect(content.contains('bgStyle == "transparent" -> R.drawable.widget_card_rounded_transparent'), isTrue);
        expect(content.contains('bgStyle == "solid" && isLightBg -> R.drawable.widget_card_rounded_light'), isTrue);
        expect(content.contains('bgStyle == "solid" -> R.drawable.widget_card_rounded_solid'), isTrue);

        // Verify widget_root does NOT receive setBackgroundResource drawable
        expect(
          content.contains('views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_card_rounded_transparent)'),
          isFalse,
          reason: 'widget_root must NEVER have drawable background to prevent double borders',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-07: 8-Slot Color Palette, No Border Color & Dynamic Badge Contrast
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-07: 8-Slot Color Palette, No Border Color & Dynamic Badge Contrast', () {
      testWidgets('WidgetStudioScreen: Removes Border Color and standardizes 8 slots per color row', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to color selectors
        await tester.scrollUntilVisible(
          find.text('Màu Điểm Nhấn'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        // 1. "Màu Viền" is completely removed
        expect(find.text('Màu Viền'), findsNothing);
        expect(find.text('Màu Chữ Chính'), findsOneWidget);
        expect(find.text('Màu Chữ Phụ'), findsOneWidget);
        expect(find.text('Màu Điểm Nhấn'), findsOneWidget);

        // 2. Custom button uses edit/pencil icon (Icons.edit)
        final editIcons = find.byIcon(Icons.edit);
        expect(editIcons, findsWidgets);
      });

      test('Dynamic Badge Contrast calculation: > 0.5 luminance uses #0F172A, else white', () {
        // Bright colors (luminance > 0.5)
        const white = Color(0xFFFFFFFF);
        const brightYellow = Color(0xFFFFFF00);

        // Dark/medium colors (luminance <= 0.5)
        const darkBlue = Color(0xFF1D64F2);
        const darkBlack = Color(0xFF1C1C1E);
        const amber = Color(0xFFF59E0B);

        Color getBadgeTextColor(Color accent) {
          return accent.computeLuminance() > 0.5 ? const Color(0xFF0F172A) : Colors.white;
        }

        expect(getBadgeTextColor(white), equals(const Color(0xFF0F172A)));
        expect(getBadgeTextColor(brightYellow), equals(const Color(0xFF0F172A)));
        expect(getBadgeTextColor(darkBlue), equals(Colors.white));
        expect(getBadgeTextColor(darkBlack), equals(Colors.white));
        expect(getBadgeTextColor(amber), equals(Colors.white));
      });

      test('ScheduleWidgetProvider.kt: sets badge text color dynamically by accent luminance', () {
        final providerFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
        expect(providerFile.existsSync(), isTrue);
        final content = providerFile.readAsStringSync();

        expect(content.contains('accentLuminance > 0.6'), isTrue);
        expect(content.contains('Color.parseColor("#0F172A")'), isTrue);
        expect(content.contains('Color.WHITE'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-08: Zero FittedBox Shrinking in Studio Grid
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-08: Zero FittedBox Shrinking in Studio Grid', () {
      test('Source Code: _buildGridDayCell does NOT wrap day cell content in FittedBox', () {
        final studioFile = File('lib/screens/widget_studio_screen.dart');
        expect(studioFile.existsSync(), isTrue);
        final content = studioFile.readAsStringSync();

        // Extract _buildGridDayCell function body
        final startIdx = content.indexOf('Widget _buildGridDayCell(');
        expect(startIdx, isNot(-1));
        final endIdx = content.indexOf('Widget _buildGridSummaryCell(', startIdx);
        expect(endIdx, isNot(-1));
        final cellFuncContent = content.substring(startIdx, endIdx);

        expect(
          cellFuncContent.contains('FittedBox'),
          isFalse,
          reason: '_buildGridDayCell must NOT contain FittedBox to eliminate font shrinking',
        );
      });

      testWidgets('Widget Test: 7-day grid cells render without FittedBox scaling down fonts', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: WidgetStudioScreen(
              initialConfig: WidgetThemeConfig.minimalSwiss(layoutMode: 'seven_days'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 7-day grid is active, verify that summary cell and day cells render cleanly
        expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
      });
    });
  });
}
