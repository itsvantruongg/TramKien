import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/widget_models.dart';
import '../lib/screens/widget_studio_screen.dart';

void main() {
  group('Iteration 19 - Task 1: Triệt tiêu 100% hiện tượng chớp nạp 2 lần trong Widget Studio', () {
    test('1.1 WidgetStudioScreen không còn gọi _fetchNativePreview() hay đè _nativePreviewBytes', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Không còn định nghĩa hay gọi _fetchNativePreview
      expect(content.contains('_fetchNativePreview'), isFalse,
          reason: 'WidgetStudioScreen đã loại bỏ hoàn toàn cơ chế _fetchNativePreview()');
      
      // Không còn đè Image.memory(_nativePreviewBytes) trong SimulatedWidgetCard
      expect(content.contains('Image.memory(_nativePreviewBytes'), isFalse,
          reason: 'Không còn cơ chế đè bitmap _nativePreviewBytes lên preview');

      // Single Source of Truth Live Preview: _buildSimulatedWidgetCard gọi _buildFlutterWidgetCard
      expect(content.contains('_buildFlutterWidgetCard()'), isTrue);
      expect(content.contains('Single Source of Truth Live Preview'), isTrue);
    });

    testWidgets('1.2 Live Preview render tức thì trong 1 frame duy nhất không chớp nạp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass(),
          ),
        ),
      );
      // Chỉ cần 1 frame pump là preview card đã xuất hiện ngay lập tức
      await tester.pump();

      expect(find.byKey(const ValueKey('flutter_fallback_card')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flutter_fallback_card')), findsOneWidget);
    });
  });

  group('Iteration 19 - Task 2: Đồng bộ Badge & Viền Highlight "HÔM NAY" cả Launcher lẫn In-App', () {
    test('2.1 Android XML Drawables: widget_today_badge_bg.xml và widget_today_highlight_bg.xml', () {
      final badgeFile = File('android/app/src/main/res/drawable/widget_today_badge_bg.xml');
      expect(badgeFile.existsSync(), isTrue);
      final badgeContent = badgeFile.readAsStringSync();
      expect(badgeContent.contains('android:radius="2.5dp"'), isTrue);

      final highlightFile = File('android/app/src/main/res/drawable/widget_today_highlight_bg.xml');
      expect(highlightFile.existsSync(), isTrue);
      final highlightContent = highlightFile.readAsStringSync();
      expect(highlightContent.contains('android:radius="8dp"'), isTrue);
    });

    test('2.2 widget_schedule_weekly.xml có grid_cell_header_container và grid_cell_badge_1..7', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      for (int i = 1; i <= 7; i++) {
        expect(content.contains('grid_cell_header_container_$i'), isTrue,
            reason: 'Container header ô $i phải tồn tại để chứa ngày và badge');
        expect(content.contains('grid_cell_badge_$i'), isTrue,
            reason: 'Badge ô $i phải tồn tại trong layout');
        
        final badgeBlock = RegExp('<TextView\\b[^>]*?grid_cell_badge_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(badgeBlock.contains('android:text="HÔM NAY"'), isTrue);
        expect(badgeBlock.contains('android:textSize="7sp"'), isTrue);
        expect(badgeBlock.contains('@drawable/widget_today_badge_bg'), isTrue);
      }
    });

    test('2.3 ScheduleWidgetProvider.kt gán badge HÔM NAY, highlight background và accentColor khi isToday == true', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('views.setViewVisibility(badgeIds[i], View.VISIBLE)'), isTrue);
      expect(content.contains('views.setInt(cellIds[i], "setBackgroundResource", R.drawable.widget_today_highlight_bg)'), isTrue);
      expect(content.contains('views.setTextColor(headerIds[i], accentColor)'), isTrue);
      expect(content.contains('views.setInt(cellIds[i], "setBackgroundResource", R.drawable.widget_grid_cell_bg)'), isTrue);
    });

    test('2.4 WidgetStudioScreen._buildGridDayCell đồng bộ viền highlight accent và badge HÔM NAY', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("'HÔM NAY'"), isTrue);
      expect(content.contains('borderRadius: BorderRadius.circular(2.5)'), isTrue);
      expect(content.contains('fontSize: 6.5') || content.contains('fontSize: 7'), isTrue);
      expect(content.contains('accent.withOpacity(0.16)'), isTrue);
      expect(content.contains('accent.withOpacity(0.85)'), isTrue);
    });
  });

  group('Iteration 19 - Task 3: Nâng cấp bố cục lấp đầy khoảng trống & Font size Lịch tuần 4x4 (Grid 8 ô)', () {
    test('3.1 widget_schedule_weekly.xml: Tiêu đề 10sp, Môn 1 (10.5sp/9sp), Môn 2 (10.5sp/9sp), Ô tổng kết 10sp/12sp/10sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra ô 1 đến 7: tiêu đề 10sp, môn 1 tên 10.5sp, hybrid 9sp, môn 2 tên 10.5sp, hybrid 9sp, sub 8.5sp
      for (int i = 1; i <= 7; i++) {
        final headerBlock = RegExp('<TextView\\b[^>]*?grid_cell_header_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(headerBlock.contains('android:textSize="10sp"'), isTrue);

        final name1Block = RegExp('<TextView\\b[^>]*?grid_cell_name_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(name1Block.contains('android:textSize="10.5sp"'), isTrue);

        final hybrid1Block = RegExp('<TextView\\b[^>]*?grid_cell_hybrid_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(hybrid1Block.contains('android:textSize="9sp"'), isTrue);

        final name2Block = RegExp('<TextView\\b[^>]*?grid_cell_class2_name_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(name2Block.contains('android:textSize="10.5sp"'), isTrue);

        final hybrid2Block = RegExp('<TextView\\b[^>]*?grid_cell_class2_hybrid_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(hybrid2Block.contains('android:textSize="9sp"'), isTrue);

        final subBlock = RegExp('<TextView\\b[^>]*?grid_cell_sub_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(subBlock.contains('android:textSize="8.5sp"'), isTrue);
      }

      // Ô 8 tổng kết tuần: title 10sp, classes 12sp, empty days 10sp
      final summaryTitleBlock = RegExp('<TextView\\b[^>]*?grid_cell_summary_title[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(summaryTitleBlock.contains('android:textSize="10sp"'), isTrue);

      final summaryClassesBlock = RegExp('<TextView\\b[^>]*?grid_cell_summary_classes[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(summaryClassesBlock.contains('android:textSize="12sp"'), isTrue);

      final summaryEmptyBlock = RegExp('<TextView\\b[^>]*?grid_cell_summary_empty_days[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(summaryEmptyBlock.contains('android:textSize="10sp"'), isTrue);
    });

    test('3.2 ScheduleWidgetProvider.kt: Phân tách Môn 2 (Tên + Giờ/Phòng) và (+N môn nữa)', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('class2NameIds'), isTrue);
      expect(content.contains('class2HybridIds'), isTrue);
      expect(content.contains('views.setTextViewText(class2NameIds[i], c2Title)'), isTrue);
      expect(content.contains('views.setTextViewText(class2HybridIds[i], c2TimeRoom)'), isTrue);
      expect(content.contains('val remaining = count - 2'), isTrue);
      expect(content.contains(r'views.setTextViewText(subIds[i], "(+$remaining môn nữa)")'), isTrue);
    });

    test('3.3 WidgetStudioScreen: _buildGridDayCell & _buildGridSummaryCell lấp đầy cân đối', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Môn 1: 10.5 và 9
      expect(content.contains('fontSize: 10.5'), isTrue);
      expect(content.contains('fontSize: 9'), isTrue);

      // Môn 2: riêng biệt tên và giờ/phòng
      expect(content.contains('final tr2 = WidgetDataSyncService.formatHybridTimeAndRoom('), isTrue);

      // Dòng cuối: 8.5 hoặc 8 (SPEC-HOTFIX)
      expect(content.contains('fontSize: 8.5') || content.contains('fontSize: 8,'), isTrue);
      expect(content.contains("'(+\${count - 2} môn nữa)'"), isTrue);

      // Ô tổng kết tuần: title 10, count 12, empty 10
      expect(content.contains("'TỔNG KẾT TUẦN'"), isTrue);
      expect(content.contains("'\$totalClasses buổi học • \$totalExams buổi thi'"), isTrue);
    });
  });
}
