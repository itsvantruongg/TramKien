import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hạng mục 1: Đồng bộ 100% màu nền Presets & Custom Color ra Launcher (ScheduleWidgetProvider.kt)', () {
    final kotlinFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');

    test('Tệp ScheduleWidgetProvider.kt tồn tại', () {
      expect(kotlinFile.existsSync(), isTrue, reason: 'Tệp ScheduleWidgetProvider.kt phải tồn tại');
    });

    test('Hàm createDynamicCardBackground tồn tại và định nghĩa đầy đủ tham số đồ họa', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('fun createDynamicCardBackground('), isTrue);
      expect(content.contains('widthPx: Int'), isTrue);
      expect(content.contains('heightPx: Int'), isTrue);
      expect(content.contains('bgColor: Int'), isTrue);
      expect(content.contains('bgOpacity: Float'), isTrue);
      expect(content.contains('borderColor: Int'), isTrue);
      expect(content.contains('borderWidthDp: Float'), isTrue);
      expect(content.contains('cornerRadiusDp: Float'), isTrue);
    });

    test('createDynamicCardBackground khởi tạo Bitmap ARGB_8888, khử răng cưa và vẽ góc bo động', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)'), isTrue);
      expect(content.contains('Paint(Paint.ANTI_ALIAS_FLAG)'), isTrue);
      expect(content.contains('canvas.drawRoundRect('), isTrue);
      expect(content.contains('cornerRadiusPx'), isTrue);
    });

    test('Xử lý vẽ stroke viền chuẩn xác khi borderWidthDp > 0f và có alpha borderColor', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('if (borderWidthPx > 0f && Color.alpha(borderColor) > 0)'), isTrue);
      expect(content.contains('style = Paint.Style.STROKE'), isTrue);
      expect(content.contains('strokeWidth = borderWidthPx'), isTrue);
      expect(content.contains('borderCornerRadius'), isTrue);
    });

    test('Nạp dynamic bitmap vào widget_bg_image và triệt tiêu lem viền đen (widget_root transparent)', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('views.setImageViewBitmap(R.id.widget_bg_image, bgBitmap)'), isTrue);
      expect(content.contains('views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)'), isTrue);
      expect(content.contains('views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
    });

    test('Xử lý Transparent mode: Ẩn widget_bg_image và dùng widget_card_rounded_transparent', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('bgStyle == "transparent" -> R.drawable.widget_card_rounded_transparent'), isTrue);
      expect(content.contains('views.setViewVisibility(R.id.widget_bg_image, View.GONE)'), isTrue);
      expect(
        content.contains('views.setInt(android.R.id.background, "setBackgroundResource", bgRes)'),
        isTrue,
      );
    });

    test('Khởi tạo kích thước bitmap và bán kính bo góc phù hợp theo từng loại layout', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('"single_day_2x2" -> Pair(450, 450)'), isTrue);
      expect(content.contains('"seven_days" -> Pair(800, 800)'), isTrue);
      expect(content.contains('else -> Pair(800, 400)'), isTrue);
      expect(content.contains('val radiusDp = 16f'), isTrue);
    });
  });

  group('Hạng mục 2: Chuẩn hóa Swiss Typography trên toàn bộ 6 layout XML Native', () {
    final layoutFiles = [
      'android/app/src/main/res/layout/widget_schedule_single_day.xml',
      'android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml',
      'android/app/src/main/res/layout/widget_schedule_three_days.xml',
      'android/app/src/main/res/layout/widget_schedule_weekly_strip.xml',
      'android/app/src/main/res/layout/widget_schedule_weekly.xml',
      'android/app/src/main/res/layout/widget_schedule_tomorrow.xml',
    ];

    test('Tất cả 6 tệp XML layout native đều tồn tại', () {
      for (final path in layoutFiles) {
        expect(File(path).existsSync(), isTrue, reason: 'Tệp $path phải tồn tại');
      }
    });

    test('100% TextView trong 6 layout XML native có đầy đủ fontFamily, letterSpacing và includeFontPadding', () {
      int totalTextViews = 0;
      final missingFontFamily = <String>[];
      final missingLetterSpacing = <String>[];
      final missingFontPadding = <String>[];

      final textViewRegex = RegExp(r'<TextView\b([^>]*?)(?:/>|>)', multiLine: true, dotAll: true);
      final idRegex = RegExp(r'android:id="([^"]+)"');
      final fontFamilyRegex = RegExp(r'android:fontFamily="([^"]+)"');
      final letterSpacingRegex = RegExp(r'android:letterSpacing="([^"]+)"');
      final fontPaddingRegex = RegExp(r'android:includeFontPadding="([^"]+)"');

      for (final path in layoutFiles) {
        final content = File(path).readAsStringSync();
        final matches = textViewRegex.allMatches(content);
        expect(matches.isNotEmpty, isTrue, reason: 'Phải tìm thấy TextView trong $path');

        for (final match in matches) {
          totalTextViews++;
          final block = match.group(1) ?? '';
          final idMatch = idRegex.firstMatch(block);
          final elemId = idMatch != null ? idMatch.group(1)! : 'unknown_id';
          final tagDesc = '$path [$elemId]';

          final ffMatch = fontFamilyRegex.firstMatch(block);
          if (ffMatch == null) {
            missingFontFamily.add(tagDesc);
          } else {
            final ffVal = ffMatch.group(1);
            expect(
              ffVal == 'sans-serif-medium' || ffVal == 'sans-serif',
              isTrue,
              reason: 'fontFamily tại $tagDesc phải là sans-serif-medium hoặc sans-serif, nhưng là $ffVal',
            );
          }

          final lsMatch = letterSpacingRegex.firstMatch(block);
          if (lsMatch == null || lsMatch.group(1) != '-0.02') {
            missingLetterSpacing.add('$tagDesc (value: ${lsMatch?.group(1)})');
          }

          final ifpMatch = fontPaddingRegex.firstMatch(block);
          if (ifpMatch == null || ifpMatch.group(1) != 'false') {
            missingFontPadding.add('$tagDesc (value: ${ifpMatch?.group(1)})');
          }
        }
      }

      expect(totalTextViews, equals(129), reason: 'Tổng số TextView tìm thấy phải đúng 129 across 6 layouts (SPEC-WIDGET-TIMELINE-TIME-RANGE)');
      expect(missingFontFamily, isEmpty, reason: 'Không có TextView nào thiếu android:fontFamily');
      expect(missingLetterSpacing, isEmpty, reason: 'Không có TextView nào thiếu hoặc sai android:letterSpacing="-0.02"');
      expect(missingFontPadding, isEmpty, reason: 'Không có TextView nào thiếu hoặc sai android:includeFontPadding="false"');
    });

    test('Chi tiết từng layout XML native đạt chuẩn Swiss Typography 100%', () {
      final counts = {
        'widget_schedule_single_day.xml': 12,
        'widget_schedule_single_day_2x2.xml': 16,
        'widget_schedule_three_days.xml': 14,
        'widget_schedule_weekly_strip.xml': 18,
        'widget_schedule_weekly.xml': 54,
        'widget_schedule_tomorrow.xml': 15,
      };

      for (final entry in counts.entries) {
        final path = 'android/app/src/main/res/layout/${entry.key}';
        final content = File(path).readAsStringSync();
        final matches = RegExp(r'<TextView\b([^>]*?)(?:/>|>)', multiLine: true, dotAll: true).allMatches(content);
        expect(matches.length, equals(entry.value), reason: '${entry.key} phải có ${entry.value} TextViews');

        for (final m in matches) {
          final block = m.group(1) ?? '';
          expect(block.contains('android:letterSpacing="-0.02"'), isTrue, reason: 'Letter spacing -0.02 trong ${entry.key}');
          expect(block.contains('android:includeFontPadding="false"'), isTrue, reason: 'includeFontPadding false trong ${entry.key}');
          expect(
            block.contains('android:fontFamily="sans-serif-medium"') || block.contains('android:fontFamily="sans-serif"'),
            isTrue,
            reason: 'fontFamily chuẩn Swiss trong ${entry.key}',
          );
        }
      }
    });
  });
}
