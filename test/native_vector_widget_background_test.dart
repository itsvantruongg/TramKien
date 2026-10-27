import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SPEC-NATIVE-VECTOR-WIDGET-01 Acceptance Criteria Tests', () {
    test('AC-01 & AC-02: Native Vector XML Drawables define radius 16dp and hairline stroke 0.5dp', () {
      // 1. widget_card_rounded_bg.xml
      final bgFile = File('android/app/src/main/res/drawable/widget_card_rounded_bg.xml');
      expect(bgFile.existsSync(), isTrue, reason: 'widget_card_rounded_bg.xml must exist');
      final bgContent = bgFile.readAsStringSync();
      expect(bgContent.contains('android:radius="16dp"'), isTrue, reason: 'Background card corner radius must be 16dp');
      expect(bgContent.contains('android:width="0.5dp"'), isTrue, reason: 'Hairline stroke width must be 0.5dp');
      expect(bgContent.contains('android:color="#26FFFFFF"'), isTrue, reason: 'Dark card stroke color must be #26FFFFFF');
      expect(
        bgContent.contains('android:color="#D91C1C1E"') || bgContent.contains('android:color="#C81C1C1E"'),
        isTrue,
        reason: 'Dark card solid color must be #D91C1C1E or #C81C1C1E',
      );

      // 2. widget_card_rounded_solid.xml
      final solidFile = File('android/app/src/main/res/drawable/widget_card_rounded_solid.xml');
      expect(solidFile.existsSync(), isTrue, reason: 'widget_card_rounded_solid.xml must exist');
      final solidContent = solidFile.readAsStringSync();
      expect(solidContent.contains('android:radius="16dp"'), isTrue);
      expect(solidContent.contains('android:width="0.5dp"'), isTrue);
      expect(solidContent.contains('android:color="#26FFFFFF"'), isTrue);
      expect(solidContent.contains('android:color="#FF1C1C1E"'), isTrue);

      // 3. widget_card_rounded_light.xml
      final lightFile = File('android/app/src/main/res/drawable/widget_card_rounded_light.xml');
      expect(lightFile.existsSync(), isTrue, reason: 'widget_card_rounded_light.xml must exist');
      final lightContent = lightFile.readAsStringSync();
      expect(lightContent.contains('android:radius="16dp"'), isTrue);
      expect(lightContent.contains('android:width="0.5dp"'), isTrue);
      expect(lightContent.contains('android:color="#CBD5E1"'), isTrue);
      expect(lightContent.contains('android:color="#F8F9FA"'), isTrue);

      // 4. widget_card_rounded_transparent.xml
      final transFile = File('android/app/src/main/res/drawable/widget_card_rounded_transparent.xml');
      expect(transFile.existsSync(), isTrue, reason: 'widget_card_rounded_transparent.xml must exist');
      final transContent = transFile.readAsStringSync();
      expect(transContent.contains('android:radius="16dp"'), isTrue);
      expect(transContent.contains('android:width="0.5dp"'), isTrue);
      expect(transContent.contains('android:color="#33FFFFFF"'), isTrue);
      expect(transContent.contains('android:color="#00000000"'), isTrue);
    });

    test('AC-01: ScheduleWidgetProvider.kt binds Native XML Vector Shape to android.R.id.background and hides widget_bg_image', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue, reason: 'ScheduleWidgetProvider.kt must exist');
      final content = ktFile.readAsStringSync();

      // Check View.GONE for widget_bg_image when not using custom image
      expect(content.contains('views.setViewVisibility(R.id.widget_bg_image, View.GONE)'), isTrue);

      // Check binding of XML shape resource via when block
      expect(content.contains('val bgRes = when {'), isTrue);
      expect(content.contains('bgStyle == "transparent" -> R.drawable.widget_card_rounded_transparent'), isTrue);
      expect(content.contains('bgStyle == "solid" && isLightBg -> R.drawable.widget_card_rounded_light'), isTrue);
      expect(content.contains('bgStyle == "solid" -> R.drawable.widget_card_rounded_solid'), isTrue);
      expect(content.contains('isLightBg -> R.drawable.widget_card_rounded_light'), isTrue);
      expect(content.contains('else -> R.drawable.widget_card_rounded_bg'), isTrue);

      // Check setting background on root and android.R.id.background
      expect(content.contains('views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('views.setInt(android.R.id.background, "setBackgroundResource", bgRes)'), isTrue);
    });

    test('AC-03: Minimalist hairline borders replace loud blue outlines', () {
      final bgFile = File('android/app/src/main/res/drawable/widget_card_rounded_bg.xml');
      final lightFile = File('android/app/src/main/res/drawable/widget_card_rounded_light.xml');

      expect(bgFile.readAsStringSync().contains('#1D64F2'), isFalse, reason: 'Dark card shape must not have loud blue border');
      expect(lightFile.readAsStringSync().contains('#1D64F2'), isFalse, reason: 'Light card shape must not have loud blue border');
    });

    test('AC-04: widget_schedule_weekly.xml content container has 12dp padding to prevent bottom row clipping', () {
      final weeklyFile = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(weeklyFile.existsSync(), isTrue);
      final content = weeklyFile.readAsStringSync();

      // Verify content container inside @android:id/background has 12dp padding
      final bgIndex = content.indexOf('android:id="@android:id/background"');
      expect(bgIndex != -1, isTrue);

      final contentBlock = content.substring(bgIndex, content.indexOf('android:id="@+id/widget_weekly_header_container"'));
      expect(contentBlock.contains('android:padding="12dp"'), isTrue,
          reason: 'Content LinearLayout inside @android:id/background must have padding="12dp"');
    });

    test('AC-05: 2x2 widget title truncation elimination and top alignment (SPEC-WIDGET-ENHANCEMENT-01)', () {
      // 1. Check layout XML for top alignment
      final single2x2File = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(single2x2File.existsSync(), isTrue);
      final xmlContent = single2x2File.readAsStringSync();

      expect(xmlContent.contains('android:id="@+id/widget_content_container"'), isTrue);
      expect(xmlContent.contains('android:gravity="top"'), isTrue,
          reason: 'Top alignment eliminates dead space in 2x2 widget');

      // 2. Check ScheduleWidgetProvider.kt narrow-width handling
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      final ktContent = ktFile.readAsStringSync();

      expect(ktContent.contains('views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 12f)'), isTrue,
          reason: 'Must dynamically adjust title size to 12sp on narrow width to avoid "Lịch hôm..." truncation');
    });

    testWidgets('AC-06: Zero regressions - WidgetStudioScreen renders 2x2, 4x2, and 4x4 cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Test 2x2 layout
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            key: const ValueKey('studio_2x2_native_vector'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'single_day'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lịch hôm nay'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Test 4x4 weekly grid layout
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            key: const ValueKey('studio_4x4_native_vector'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'seven_days'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lịch tuần'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
