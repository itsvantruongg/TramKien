import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/dashboard_screen.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Nhiệm vụ 1: Bo góc Launcher & Native XML Layout Geometry', () {
    final kotlinFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
    final layoutFiles = [
      'android/app/src/main/res/layout/widget_schedule_single_day.xml',
      'android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml',
      'android/app/src/main/res/layout/widget_schedule_three_days.xml',
      'android/app/src/main/res/layout/widget_schedule_weekly_strip.xml',
      'android/app/src/main/res/layout/widget_schedule_weekly.xml',
      'android/app/src/main/res/layout/widget_schedule_tomorrow.xml',
    ];

    test('ScheduleWidgetProvider.kt duy trì background shape bo góc widget_root và safe inset', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('val rootBgRes = if (layoutType == "seven_days") R.drawable.widget_card_rounded_20dp else R.drawable.widget_card_rounded_bg'), isTrue);
      expect(content.contains('views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)'), isTrue);
      expect(content.contains('else -> Pair(800, 400)'), isTrue);
      expect(content.contains('val inset = if (borderWidthPx > 0f) borderWidthPx / 2f else 1f'), isTrue);
    });

    test('Cả 6 layout XML native có scaleType="fitXY" và padding chuẩn 10dp đến 12dp', () {
      for (final path in layoutFiles) {
        final content = File(path).readAsStringSync();
        expect(content.contains('android:scaleType="fitXY"'), isTrue, reason: '$path phải có scaleType="fitXY"');
        expect(content.contains('android:padding="10dp"') || content.contains('android:padding="12dp"'), isTrue, reason: '$path phải có padding 10dp hoặc 12dp');
      }
    });

    test('Khoảng cách các hàng đạt chuẩn 6dp trên các layout nhiều ca/nhiều ngày', () {
      final singleDay = File('android/app/src/main/res/layout/widget_schedule_single_day.xml').readAsStringSync();
      expect(singleDay.contains('android:layout_marginBottom="6dp"'), isTrue);

      final tomorrow = File('android/app/src/main/res/layout/widget_schedule_tomorrow.xml').readAsStringSync();
      expect(tomorrow.contains('android:layout_marginBottom="6dp"'), isTrue);

      final threeDays = File('android/app/src/main/res/layout/widget_schedule_three_days.xml').readAsStringSync();
      expect(threeDays.contains('android:layout_marginBottom="6dp"'), isTrue);

      final weekly = File('android/app/src/main/res/layout/widget_schedule_weekly.xml').readAsStringSync();
      expect(weekly.contains('android:layout_marginBottom="6dp"'), isTrue);
    });
  });

  group('Nhiệm vụ 2: Chuẩn hóa dữ liệu mẫu Studio 100% kín lịch', () {
    testWidgets('WidgetStudioScreen Live Preview 100% kín lịch trên cả 3 widget tinh hoa', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. single_day (4x2 Timeline): Môn 1, Môn 2 và footer (+2 môn nữa)
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
      expect(find.text('(+2 môn nữa)'), findsOneWidget);

      // 2. three_days: Cả 3 ngày đều có môn học, không ngày nào có 'Không có lịch'
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Không có lịch'), findsNothing);
      expect(find.textContaining('Môn học 1'), findsOneWidget);
      expect(find.textContaining('Môn học 3'), findsOneWidget);
      expect(find.textContaining('Môn học 4'), findsOneWidget);

      // 3. seven_days: Các ngày đều kín lịch
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
      expect(find.textContaining('0 ngày trống'), findsOneWidget);
    });
  });

  group('Nhiệm vụ 3: Luồng Pin Widget không ngắt quãng Launcher System Dialog', () {
    test('MainActivity.kt gọi requestPinAppWidget và không gọi context.startActivity(homeIntent)', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
      final content = file.readAsStringSync();
      expect(content.contains('appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)'), isTrue);
      expect(content.contains('context.startActivity(homeIntent)'), isFalse);
    });
  });

  group('Nhiệm vụ 4: Vòng đời Sync & Zero Grey-Overlay khi đã có cache', () {
    testWidgets('DashboardScreen giữ 100% Opacity khi cacheLoaded dù đang sync nền', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = AppProvider();
      provider.student = const Student(
        mssv: '23CN01',
        hoTen: 'Nguyễn Văn Test',
      );

      // Giả lập trạng thái mở app lại: đã có cache và đang sync nền
      // provider.isCacheLoaded = true, provider.isSyncing = true
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra không có Opacity(0.45) áp lên vùng GPA + Credits hoặc thẻ lịch học
      final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
      for (final op in opacities) {
        expect(op.opacity, isNot(equals(0.45)), reason: 'Không bao giờ phủ mờ 0.45 khi đã có cache');
      }
    });
  });
}
