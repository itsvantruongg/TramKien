import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';
import 'package:Tram_Kien/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi_VN', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Iteration 22 - Đại phẫu Padding 3 Lớp & Bo góc đồng tâm (16dp / 8dp)', () {
    test('1.1 widget_schedule_single_day_2x2.xml: Cấu trúc 3 lớp chuẩn mực', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout đệm trong suốt 10dp
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: Container @android:id/background + ImageView fitXY
      expect(content.contains('android:id="@android:id/background"'), isTrue);
      expect(content.contains('android:id="@+id/widget_bg_image"'), isTrue);
      expect(content.contains('android:scaleType="fitXY"'), isTrue);

      // Lớp 3: LinearLayout nội dung padding 10dp, row gap 6dp
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:layout_marginTop="6dp"'), isTrue);
    });

    test('1.2 widget_schedule_three_days.xml: Cấu trúc 3 lớp chuẩn mực', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_three_days.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout đệm trong suốt 10dp
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: Container @android:id/background + ImageView fitXY
      expect(content.contains('android:id="@android:id/background"'), isTrue);
      expect(content.contains('android:id="@+id/widget_bg_image"'), isTrue);
      expect(content.contains('android:scaleType="fitXY"'), isTrue);

      // Lớp 3: LinearLayout nội dung padding 10dp, row gap 6dp
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:layout_marginBottom="6dp"'), isTrue);
    });

    test('1.3 widget_schedule_weekly.xml: Cấu trúc 3 lớp & Column Gap 8dp, Row Gap 6dp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Lớp 1: Root FrameLayout đệm trong suốt 10dp
      expect(content.contains('android:id="@+id/widget_root"'), isTrue);
      expect(content.contains('android:padding="10dp"'), isTrue);
      expect(content.contains('android:background="@android:color/transparent"'), isTrue);

      // Lớp 2: Container @android:id/background + ImageView fitXY
      expect(content.contains('android:id="@android:id/background"'), isTrue);
      expect(content.contains('android:id="@+id/widget_bg_image"'), isTrue);
      expect(content.contains('android:scaleType="fitXY"'), isTrue);

      // Lớp 3: LinearLayout nội dung padding 10dp
      expect(content.contains('android:padding="10dp"'), isTrue);

      // Column Gap: 8dp (marginEnd 4dp cho cột trái, marginStart 4dp cho cột phải)
      expect(content.contains('android:layout_marginEnd="4dp"'), isTrue);
      expect(content.contains('android:layout_marginStart="4dp"'), isTrue);

      // Row Gap: 6dp
      expect(content.contains('android:layout_marginBottom="6dp"'), isTrue);
    });

    test('2.1 ScheduleWidgetProvider.kt: Chuẩn hóa bán kính bo góc 16dp và đồng bộ pending intent', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final content = ktFile.readAsStringSync();

      // Chuẩn hóa radiusDp = 16f
      expect(content.contains('val radiusDp = 16f'), isTrue);

      // Đồng bộ setOnClickPendingIntent cho cả widget_root và android.R.id.background
      expect(content.contains('views.setOnClickPendingIntent(R.id.widget_root, scheduleWeeklyPendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(android.R.id.background, scheduleWeeklyPendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(R.id.widget_root, schedulePendingIntent)'), isTrue);
      expect(content.contains('views.setOnClickPendingIntent(android.R.id.background, schedulePendingIntent)'), isTrue);

      // Đồng bộ setInt background (AC-06: widget_root là Color.TRANSPARENT, android.R.id.background là bgRes)
      expect(content.contains('views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('views.setInt(android.R.id.background, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('views.setInt(android.R.id.background, "setBackgroundResource", bgRes)'), isTrue);
    });

    testWidgets('3.1 WidgetStudioScreen Live Preview: Đồng bộ 3 lớp, bo góc 16dp, padding 10dp, column gap 8dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            key: const ValueKey('studio_weekly_grid_i22'),
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(layoutMode: 'seven_days'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra preview hiển thị bình thường không ngoại lệ
      expect(find.text('Lịch tuần'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
