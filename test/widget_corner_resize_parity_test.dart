import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SPEC-WIDGET-CORNER-RESIZE-01 Acceptance Criteria Verification Tests', () {
    test('AC-01 (Android v31 System Radius Resources): attrs.xml and themes.xml define appWidgetRadius & appWidgetInnerRadius', () {
      // 1. Check attrs.xml
      final attrsFile = File('android/app/src/main/res/values/attrs.xml');
      expect(attrsFile.existsSync(), isTrue, reason: 'android/app/src/main/res/values/attrs.xml must exist');
      final attrsContent = attrsFile.readAsStringSync();
      expect(attrsContent.contains('<declare-styleable name="AppWidgetAttrs">'), isTrue,
          reason: 'attrs.xml must declare AppWidgetAttrs styleable');
      expect(attrsContent.contains('<attr name="appWidgetRadius" format="dimension" />'), isTrue,
          reason: 'attrs.xml must declare appWidgetRadius attribute');
      expect(attrsContent.contains('<attr name="appWidgetInnerRadius" format="dimension" />'), isTrue,
          reason: 'attrs.xml must declare appWidgetInnerRadius attribute');

      // 2. Check values/themes.xml
      final themesFile = File('android/app/src/main/res/values/themes.xml');
      expect(themesFile.existsSync(), isTrue, reason: 'android/app/src/main/res/values/themes.xml must exist');
      final themesContent = themesFile.readAsStringSync();
      expect(themesContent.contains('name="Theme.TramKien.AppWidgetContainerParent"'), isTrue,
          reason: 'themes.xml must declare Theme.TramKien.AppWidgetContainerParent');
      expect(themesContent.contains('parent="@android:style/Theme.DeviceDefault"'), isTrue,
          reason: 'Theme.TramKien.AppWidgetContainerParent must inherit from @android:style/Theme.DeviceDefault');
      expect(themesContent.contains('<item name="appWidgetRadius">16dp</item>'), isTrue,
          reason: 'Default appWidgetRadius must be 16dp');
      expect(themesContent.contains('<item name="appWidgetInnerRadius">8dp</item>'), isTrue,
          reason: 'Default appWidgetInnerRadius must be 8dp');

      // 3. Check values-v31/themes.xml
      final v31ThemesFile = File('android/app/src/main/res/values-v31/themes.xml');
      expect(v31ThemesFile.existsSync(), isTrue, reason: 'android/app/src/main/res/values-v31/themes.xml must exist');
      final v31Content = v31ThemesFile.readAsStringSync();
      expect(v31Content.contains('name="Theme.TramKien.AppWidgetContainerParent"'), isTrue,
          reason: 'values-v31/themes.xml must declare Theme.TramKien.AppWidgetContainerParent');
      expect(v31Content.contains('parent="@android:style/Theme.DeviceDefault.DayNight"'), isTrue,
          reason: 'values-v31 theme must inherit from @android:style/Theme.DeviceDefault.DayNight');
      expect(v31Content.contains('<item name="appWidgetRadius">@android:dimen/system_app_widget_background_radius</item>'), isTrue,
          reason: 'v31 theme must link appWidgetRadius to system_app_widget_background_radius');
      expect(v31Content.contains('<item name="appWidgetInnerRadius">@android:dimen/system_app_widget_inner_radius</item>'), isTrue,
          reason: 'v31 theme must link appWidgetInnerRadius to system_app_widget_inner_radius');
    });

    test('AC-02 (Android Dynamic Size Query & Density Conversion): calculateWidgetDimensions converts minWidth/minHeight to target pixels', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue, reason: 'ScheduleWidgetProvider.kt must exist');
      final content = ktFile.readAsStringSync();

      expect(content.contains('calculateWidgetDimensions'), isTrue,
          reason: 'ScheduleWidgetProvider.kt must implement calculateWidgetDimensions');
      expect(content.contains('AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH'), isTrue,
          reason: 'Must query OPTION_APPWIDGET_MIN_WIDTH from widget options');
      expect(content.contains('AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT'), isTrue,
          reason: 'Must query OPTION_APPWIDGET_MIN_HEIGHT from widget options');
      expect(content.contains('minWidthDp * density') || content.contains('targetWidthPx'), isTrue,
          reason: 'Must convert minWidthDp with screen density');
      expect(content.contains('minHeightDp * density') || content.contains('targetHeightPx'), isTrue,
          reason: 'Must convert minHeightDp with screen density');

      // Fallback verification
      expect(content.contains('Pair(450, 450)'), isTrue,
          reason: 'Must retain safe fallback for single_day_2x2 (450x450)');
      expect(content.contains('Pair(800, 800)'), isTrue,
          reason: 'Must retain safe fallback for seven_days (800x800)');
      expect(content.contains('Pair(800, 400)'), isTrue,
          reason: 'Must retain safe fallback for three_days (800x400)');
    });

    test('AC-03 (Android Resize Event Listener): onAppWidgetOptionsChanged triggers update with new dimensions', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final content = ktFile.readAsStringSync();

      expect(content.contains('override fun onAppWidgetOptionsChanged'), isTrue,
          reason: 'ScheduleWidgetProvider must override onAppWidgetOptionsChanged');
      expect(content.contains('newOptions: Bundle'), isTrue,
          reason: 'onAppWidgetOptionsChanged must receive newOptions: Bundle');
      expect(content.contains('super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)'), isTrue,
          reason: 'Must invoke super.onAppWidgetOptionsChanged');
      expect(content.contains('updateAppWidget(context, appWidgetManager, appWidgetId, themeJsonStr, dataJsonStr, layoutResId, layoutType, newOptions)'), isTrue,
          reason: 'onAppWidgetOptionsChanged must pass newOptions to updateAppWidget');
    });

    test('AC-04 (Anti-Distortion Geometry Verification): dynamic widthPx & heightPx passed to card background & image overlay', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final content = ktFile.readAsStringSync();

      // createDynamicCardBackground uses dynamic widthPx and heightPx
      expect(content.contains('val bgBitmap = createDynamicCardBackground('), isTrue);
      expect(content.contains('widthPx = widthPx,'), isTrue,
          reason: 'createDynamicCardBackground must use dynamic widthPx');
      expect(content.contains('heightPx = heightPx,'), isTrue,
          reason: 'createDynamicCardBackground must use dynamic heightPx');

      // createRoundedBitmapWithOverlay supports targetWidthPx and targetHeightPx to eliminate 1.66 ratio distortion
      expect(content.contains('targetWidthPx: Int = src.width'), isTrue,
          reason: 'createRoundedBitmapWithOverlay must accept targetWidthPx with fallback');
      expect(content.contains('targetHeightPx: Int = src.height'), isTrue,
          reason: 'createRoundedBitmapWithOverlay must accept targetHeightPx with fallback');
      expect(content.contains('createRoundedBitmapWithOverlay(context, original, radiusDp, 130, widthPx, heightPx)'), isTrue,
          reason: 'Must render custom background image with real widget aspect ratio');
    });

    test('AC-05 (iOS 17+ containerBackground Support): ScheduleWidgetKit.swift provides widgetBackgroundAdaptive extension', () {
      final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
      expect(swiftFile.existsSync(), isTrue, reason: 'ios/Runner/ScheduleWidgetKit.swift must exist');
      final content = swiftFile.readAsStringSync();

      expect(content.contains('func widgetBackgroundAdaptive(isGlass: Bool, bgColorHex: String, bgOpacity: Double) -> some View'), isTrue,
          reason: 'Must declare widgetBackgroundAdaptive helper on View');
      expect(content.contains('#available(iOSApplicationExtension 17.0, iOS 17.0, *)'), isTrue,
          reason: 'Must check for iOS 17+ availability');
      expect(content.contains('containerBackground(for: .widget)'), isTrue,
          reason: 'Must use containerBackground(for: .widget) on iOS 17+');
      expect(content.contains('background('), isTrue,
          reason: 'Must provide background() fallback on older iOS');
      expect(content.contains('.widgetBackgroundAdaptive('), isTrue,
          reason: 'ScheduleWidgetView must apply .widgetBackgroundAdaptive modifier');
      expect(content.contains('let bgColorHex: String'), isTrue,
          reason: 'ScheduleWidgetEntry must store bgColorHex');
    });

    test('AC-06 (iOS Content Margins Disabled): disableContentMarginsIfNeeded applied to ScheduleWidget', () {
      final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
      expect(swiftFile.existsSync(), isTrue);
      final content = swiftFile.readAsStringSync();

      expect(content.contains('extension WidgetConfiguration'), isTrue,
          reason: 'Must declare WidgetConfiguration extension');
      expect(content.contains('func disableContentMarginsIfNeeded() -> some WidgetConfiguration'), isTrue,
          reason: 'Must declare disableContentMarginsIfNeeded() on WidgetConfiguration');
      expect(content.contains('contentMarginsDisabled()'), isTrue,
          reason: 'Must call contentMarginsDisabled() when available');
      expect(content.contains('.disableContentMarginsIfNeeded()'), isTrue,
          reason: 'ScheduleWidget.body must call .disableContentMarginsIfNeeded()');
    });
  });
}
