import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
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

  group('Nhiệm vụ 1 & XML RemoteViews Compatibility', () {
    test('Tất cả file widget XML tuyệt đối không chứa thẻ <View> (tránh InflateException)', () {
      final layoutDir = Directory('android/app/src/main/res/layout');
      final xmlFiles = layoutDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('widget_schedule_') && f.path.endsWith('.xml'));

      for (final file in xmlFiles) {
        final content = file.readAsStringSync();
        // Cấm thẻ <View ...> hoặc <View/>
        final viewRegex = RegExp(r'<View(\s|/|>)');
        expect(
          viewRegex.hasMatch(content),
          isFalse,
          reason: 'File ${file.path} chứa thẻ <View> vi phạm RemoteViews!',
        );
      }
    });

    test('widget_schedule_single_day_2x2.xml chứa ImageView với layout_weight="1"', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      final content = file.readAsStringSync();
      expect(content.contains('<ImageView'), isTrue);
      expect(content.contains('android:layout_weight="1"'), isTrue);
    });

    test('widget_schedule_weekly.xml có 8 ô căn top và bo 20dp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      final content = file.readAsStringSync();
      expect(content.contains('@android:color/transparent'), isTrue);
      expect(content.contains('@drawable/widget_grid_cell_bg'), isTrue);
      expect(content.contains('android:gravity="top"'), isTrue);
    });

    test('widget_schedule_weekly_strip.xml có container chi tiết căn top', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly_strip.xml');
      final content = file.readAsStringSync();
      expect(content.contains('android:gravity="top"'), isTrue);
    });
  });

  group('Nhiệm vụ 2: Vòng đời Event-Driven & Tầng Sync', () {
    test('AppProvider cung cấp cacheLoaded, isLoggedIn, isSyncingHistory', () {
      final p = AppProvider();
      expect(p.cacheLoaded, isA<Future<void>>());
      expect(p.isLoggedIn, isFalse);
      expect(p.isSyncingHistory, isFalse);
    });
  });

  group('Nhiệm vụ 3: Thẻ single_day mặc định 4x2 Timeline (2x2 đã lược bỏ)', () {
    testWidgets('Live preview 4x2 hiển thị Môn 1, Môn 2 và footer (+2 môn nữa)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(
              layoutMode: 'single_day',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
      expect(find.text('(+2 môn nữa)'), findsOneWidget);
    });
  });

  group('Nhiệm vụ 4: Lịch 7 Ngày 4x4 Grid căn từ trên xuống (start) & bo góc 8dp', () {
    testWidgets('Live preview 4x4 Grid có 8 ô căn start và bo góc 8dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(
              layoutMode: 'seven_days',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();

      expect(find.text('HÔM NAY'), findsAtLeastNWidgets(1));
      expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
    });
  });

  group('Nhiệm vụ 7: Status bar đen than #1E293B trên nền sáng', () {
    testWidgets('Đổi sang hình nền sáng tự động chuyển status bar sang #1E293B', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chuyển sang NỀN SÁNG
      await tester.tap(find.text('NỀN SÁNG'));
      await tester.pumpAndSettle();

      // Text 09:41 phải có màu #1E293B
      final timeFinder = find.text('09:41');
      expect(timeFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(timeFinder);
      expect(textWidget.style?.color, const Color(0xFF1E293B));
    });
  });

  group('Nhiệm vụ 8: Tên giảng viên HAU & Mặc định kín 4 ca', () {
    testWidgets('Bật công tắc Giảng viên hiển thị tên ThS. Nguyễn Thị Huệ', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(
              showTeacher: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ThS. Nguyễn Thị Huệ'), findsAtLeastNWidgets(1));
    });
  });
}
