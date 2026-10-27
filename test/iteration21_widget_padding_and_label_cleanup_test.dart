import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/widget_models.dart';
import '../lib/screens/widget_studio_screen.dart';

void main() {
  group('Iteration 21 - Task 1: Lược bỏ hoàn toàn (4x2), (4x4), (2x2) trong tên widget', () {
    test('1.1 AndroidManifest.xml: Nhãn widget sạch, không chứa tiền tố hoặc hậu tố kích thước (2x2, 4x2, 4x4)', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      // Kiểm tra SingleDayScheduleWidgetProvider (SPEC-WIDGET-CLEANUP-2X2: 2x2 đã lược bỏ)
      expect(
        content.contains('android:name=".SingleDayScheduleWidgetProvider"'),
        isTrue,
        reason: 'Phải khai báo SingleDayScheduleWidgetProvider',
      );
      final singleDayBlock = content.substring(
        content.indexOf('android:name=".SingleDayScheduleWidgetProvider"'),
        content.indexOf('widget_schedule_single_day_info'),
      );
      expect(
        singleDayBlock.contains('android:label="Lịch hôm nay (4x2 Timeline)"') ||
        singleDayBlock.contains('android:label="Lịch hôm nay"'),
        isTrue,
        reason: 'SingleDayScheduleWidgetProvider phải có nhãn hợp lệ',
      );

      // Kiểm tra ThreeDaysScheduleWidgetProvider
      expect(
        content.contains('android:name=".ThreeDaysScheduleWidgetProvider"'),
        isTrue,
        reason: 'Phải khai báo ThreeDaysScheduleWidgetProvider',
      );
      final threeDaysBlock = content.substring(
        content.indexOf('android:name=".ThreeDaysScheduleWidgetProvider"'),
        content.indexOf('widget_schedule_three_days_info'),
      );
      expect(
        threeDaysBlock.contains('android:label="Lịch 3 ngày"'),
        isTrue,
        reason: 'ThreeDaysScheduleWidgetProvider phải có nhãn "Lịch 3 ngày"',
      );
      expect(threeDaysBlock.contains('(4x2)'), isFalse);

      // Kiểm tra WeeklyScheduleWidgetProvider
      expect(
        content.contains('android:name=".WeeklyScheduleWidgetProvider"'),
        isTrue,
        reason: 'Phải khai báo WeeklyScheduleWidgetProvider',
      );
      final weeklyBlock = content.substring(
        content.indexOf('android:name=".WeeklyScheduleWidgetProvider"'),
        content.indexOf('widget_schedule_weekly_info'),
      );
      expect(
        weeklyBlock.contains('android:label="Lịch tuần"'),
        isTrue,
        reason: 'WeeklyScheduleWidgetProvider phải có nhãn "Lịch tuần"',
      );
      expect(weeklyBlock.contains('(4x4)'), isFalse);
    });

    test('1.2 lib/screens/widget_studio_screen.dart: Selector modes sạch không chứa hậu tố kích thước', () {
      final studioFile = File('lib/screens/widget_studio_screen.dart');
      expect(studioFile.existsSync(), isTrue);
      final content = studioFile.readAsStringSync();

      // Kiểm tra selector modes trong _buildLayoutModeSelector
      expect(content.contains("('single_day', 'Lịch hôm nay')"), isTrue);
      expect(content.contains("('three_days', 'Lịch 3 ngày')"), isTrue);
      expect(content.contains("('seven_days', 'Lịch tuần')"), isTrue);

      expect(content.contains("'Lịch hôm nay (2x2)'"), isFalse);
      expect(content.contains("'Lịch 3 ngày (4x2)'"), isFalse);
      expect(content.contains("'Lịch tuần (4x4)'"), isFalse);
    });

    test('1.3 lib/screens/widget_studio_screen.dart: previewTitle không chứa suffix kích thước (4x2, 4x4, 2x2)', () {
      final studioFile = File('lib/screens/widget_studio_screen.dart');
      expect(studioFile.existsSync(), isTrue);
      final content = studioFile.readAsStringSync();

      expect(content.contains("previewTitleSuffix = '1 NGÀY';"), isTrue);
      expect(content.contains("previewTitleSuffix = '3 NGÀY';"), isTrue);
      expect(content.contains("previewTitleSuffix = _weeklyVariant == 'grid'"), isTrue);
      expect(content.contains("'LIVE PREVIEW (\$previewTitleSuffix)'"), isTrue);

      expect(content.contains("'LIVE PREVIEW (2x2)'"), isFalse);
      expect(content.contains("'LIVE PREVIEW (4x2)'"), isFalse);
      expect(content.contains("'LIVE PREVIEW (4x4)'"), isFalse);
    });
  });

  group('Iteration 21 - Task 2: Đồng bộ dữ liệu mẫu Live Preview 4x4 (Đều 1 môn/ngày)', () {
    test('2.1 WidgetStudioScreen._buildFallbackPreviewData: 7 ngày đều có đúng 1 môn học mẫu đối xứng', () {
      final studioFile = File('lib/screens/widget_studio_screen.dart');
      expect(studioFile.existsSync(), isTrue);
      final content = studioFile.readAsStringSync();

      expect(content.contains('final sampleClassesForDays = ['), isTrue);
      expect(content.contains('[sampleClasses[0]], // Thứ 2: Môn 1'), isTrue);
      expect(content.contains('[sampleClasses[1]], // Thứ 3: Môn 2'), isTrue);
      expect(content.contains('[sampleClasses[2]], // Thứ 4: Môn 3'), isTrue);
      expect(content.contains('[sampleClasses[3]], // Thứ 5: Môn 4'), isTrue);
      expect(content.contains('[sampleClasses[0]], // Thứ 6: Môn 1'), isTrue);
      expect(content.contains('[sampleClasses[1]], // Thứ 7: Môn 2'), isTrue);
      expect(content.contains('[sampleClasses[2]], // Chủ nhật: Môn 3'), isTrue);
    });

    testWidgets('2.2 WidgetStudioScreen Live Preview 4x4: Render 7 ngày đều có 1 môn học mẫu và 1 ô tổng kết', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            key: const ValueKey('studio_weekly_grid'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'seven_days'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề Lịch tuần
      expect(find.text('Lịch tuần'), findsWidgets);

      // Kiểm tra các môn học mẫu xuất hiện đối xứng trên các ô ngày
      expect(find.text('Môn học 1'), findsNWidgets(2)); // Thứ 2 & Thứ 6
      expect(find.text('Môn học 2'), findsNWidgets(2)); // Thứ 3 & Thứ 7
      expect(find.text('Môn học 3'), findsNWidgets(2)); // Thứ 4 & Chủ nhật
      expect(find.text('Môn học 4'), findsOneWidget);   // Thứ 5

      // Ô tổng kết tuần
      expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
    });
  });

  group('Iteration 21 - Task 3: Kiến trúc Padding 3 Lớp & Bo góc đồng tâm (Concentric 3-Layer)', () {
    test('3.1 widget_schedule_single_day_2x2.xml: Tuân thủ cấu trúc 3 lớp padding và background id', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout có padding 10dp và transparent background
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: FrameLayout mang id @android:id/background
      expect(content.contains('android:id="@android:id/background"'), isTrue, reason: 'Phải có container @android:id/background');

      // Lớp 3: LinearLayout nội dung có padding 10dp
      expect(content.contains('android:padding="10dp"'), isTrue, reason: 'Nội dung phải có padding 10dp');
    });

    test('3.2 widget_schedule_three_days.xml: Tuân thủ cấu trúc 3 lớp padding và background id', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_three_days.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout có padding 10dp và transparent background
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: FrameLayout mang id @android:id/background
      expect(content.contains('android:id="@android:id/background"'), isTrue);

      // Lớp 3: LinearLayout nội dung có padding 10dp
      expect(content.contains('android:padding="10dp"'), isTrue);
    });

    test('3.3 widget_schedule_weekly.xml: Tuân thủ cấu trúc 3 lớp padding và background id', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout có padding 10dp và transparent background
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: FrameLayout mang id @android:id/background
      expect(content.contains('android:id="@android:id/background"'), isTrue);

      // Lớp 3: LinearLayout nội dung có padding 10dp
      expect(content.contains('android:padding="10dp"'), isTrue);
    });

    test('3.4 ScheduleWidgetProvider.kt: Đồng bộ set background và click pending intent cho cả widget_root và android.R.id.background', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra đồng bộ setOnClickPendingIntent
      expect(content.contains('views.setOnClickPendingIntent(R.id.widget_root, scheduleWeeklyPendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(android.R.id.background, scheduleWeeklyPendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(R.id.widget_root, schedulePendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(android.R.id.background, schedulePendingIntent)'), isTrue);

      // Kiểm tra đồng bộ setInt background (AC-06: widget_root là Color.TRANSPARENT, android.R.id.background là bgRes)
      expect(content.contains('views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('views.setInt(android.R.id.background, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('views.setInt(android.R.id.background, "setBackgroundResource", bgRes)'), isTrue);
    });
  });
}
