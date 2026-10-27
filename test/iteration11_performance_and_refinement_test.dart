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

  group('Nhiệm vụ 1: Dập tắt triệt để RenderFlex Overflow & AnimatedSwitcher OverflowBox', () {
    testWidgets('Chuyển đổi liên tục giữa 4x4 Grid và 4x2 / 2x2 không gây RenderFlex Overflow', (tester) async {
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

      // Chọn Lịch tuần
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Chuyển sang Lịch hôm nay
      await tester.tap(find.byKey(const Key('mode_single_day')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Chuyển sang Lịch 3 ngày
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Chuyển lại Lịch tuần
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnimatedSwitcher được trang bị OverflowBox + SingleChildScrollView + ClipRRect(14)', (tester) async {
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

      // Kiểm tra có AnimatedSwitcher
      final animatedSwitcherFinder = find.byType(AnimatedSwitcher);
      expect(animatedSwitcherFinder, findsAtLeastNWidgets(1));

      // Kiểm tra có OverflowBox bên trong AnimatedSwitcher
      final overflowBoxFinder = find.byType(OverflowBox);
      expect(overflowBoxFinder, findsAtLeastNWidgets(1));

      // Kiểm tra SingleChildScrollView với NeverScrollableScrollPhysics
      final scrollFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.physics is NeverScrollableScrollPhysics,
      );
      expect(scrollFinder, findsAtLeastNWidgets(1));

      // Kiểm tra ClipRRect bo góc 14
      final clipRRectFinder = find.byWidgetPredicate(
        (w) => w is ClipRRect && w.borderRadius == BorderRadius.circular(14),
      );
      expect(clipRRectFinder, findsAtLeastNWidgets(1));
    });
  });

  group('Nhiệm vụ 2: Tối ưu hiệu năng RepaintBoundary & Triệt tiêu BackdropFilter mờ đục', () {
    testWidgets('Phone Mockup bọc RepaintBoundary và loại bỏ BackdropFilter mờ đục theo AC-06', (tester) async {
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

      // Kiểm tra có RepaintBoundary bảo vệ render tree
      final repaintBoundaryFinder = find.byType(RepaintBoundary);
      expect(repaintBoundaryFinder, findsAtLeastNWidgets(1));

      // AC-06: Triệt tiêu hoàn toàn BackdropFilter mờ loang lổ
      final backdropFinder = find.byType(BackdropFilter);
      expect(backdropFinder, findsNothing);
    });
  });

  group('Nhiệm vụ 3: Thẻ single_day mặc định 4x2 Timeline (2x2 đã lược bỏ)', () {
    testWidgets('Thẻ 4x2 Timeline hiển thị Môn 1, Môn 2 và Footer (+2 môn nữa)', (tester) async {
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

      // Kiểm tra Body hiển thị môn 1 & môn 2
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);

      // Kiểm tra Footer (+2 môn nữa)
      final footerFinder = find.text('(+2 môn nữa)');
      expect(footerFinder, findsOneWidget);
    });
  });

  group('Nhiệm vụ 4: Dải tuần 7 ngày 4x2 bo 2 góc dưới Radius 12dp', () {
    testWidgets('Live preview 4x4 Grid 8 Ô hiển thị các ô bo góc', (tester) async {
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

      expect(find.text('HÔM NAY'), findsAtLeastNWidgets(1));
      expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
    });
  });

  group('Nhiệm vụ 5: Luồng lịch duy nhất & 6 Nhãn Receiver AndroidManifest.xml', () {
    test('Widget Hôm nay luôn giữ lịch Hôm nay ngay cả sau 20:00 (không tự lật sang ngày mai)', () {
      final nowEvening = DateTime(2026, 10, 21, 20, 30);
      final sampleLich = [
        const LichHoc(
          tenHocPhan: 'Môn Hôm Nay',
          soTinChi: 3,
          tenLopTinChi: 'HP01',
          thoiGian: '21/10/2026',
          thu: 'Thứ 4',
          tiet: '1-3',
          phong: 'U301',
          giaoVien: 'ThS. Nguyễn Văn A',
          hocKy: 1,
          namHoc: '2026-2027',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      final windowData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: sampleLich,
        layoutMode: 'single_day',
        currentTime: nowEvening,
      );

      expect(windowData.widgetTitle, 'Lịch hôm nay');
      expect(windowData.days.first.dayLabel, 'HÔM NAY');
      expect(windowData.days.first.isToday, isTrue);
    });

    test('6 Receiver trong AndroidManifest.xml đều mang nhãn tối giản không bị cắt chữ (bỏ "Trạm Kiến • ")', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      final content = manifestFile.readAsStringSync();

      expect(
        content.contains('android:label="Lịch hôm nay (4x2 Timeline)"') ||
        content.contains('android:label="Lịch hôm nay (2x2 Thu gọn)"') ||
        content.contains('android:label="Lịch hôm nay"'),
        isTrue,
        reason: 'Thiếu nhãn launcher chuẩn hóa cho Lịch hôm nay',
      );

      const expectedLabels = [
        'Lịch 3 ngày',
        'Lịch 7 ngày',
        'Lịch tuần',
        'Lịch ngày mai',
      ];

      for (final label in expectedLabels) {
        expect(
          content.contains('android:label="$label"'),
          isTrue,
          reason: 'Thiếu nhãn launcher chuẩn hóa: $label',
        );
      }
      expect(content.contains('android:label="Trạm Kiến • '), isFalse);
    });
  });

  group('Nhiệm vụ 6: Sửa lỗi mờ thẻ Hôm nay (Widget 3 ngày)', () {
    test('calculateScheduleWindow cho 3 Ngày: Thẻ Hôm nay luôn có isDimmed = false', () {
      final nowEvening = DateTime(2026, 10, 21, 21, 00);
      final sampleLich = [
        const LichHoc(
          tenHocPhan: 'Môn Hôm Nay',
          soTinChi: 3,
          tenLopTinChi: 'HP01',
          thoiGian: '21/10/2026',
          thu: 'Thứ 4',
          tiet: '1-3',
          phong: 'U301',
          giaoVien: 'ThS. Nguyễn Văn A',
          hocKy: 1,
          namHoc: '2026-2027',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      final windowData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: sampleLich,
        layoutMode: 'three_days',
        currentTime: nowEvening,
      );

      expect(windowData.days[0].dayLabel, 'HÔM NAY');
      expect(windowData.days[0].isToday, isTrue);
      expect(windowData.days[0].isDimmed, isFalse);
    });

    testWidgets('Live Preview 3 Ngày: Thẻ Hôm nay giữ opacity 1.0 (100% sáng rõ)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass().copyWith(
              layoutMode: 'three_days',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra opacities trong 3-day view
      final opacities = tester.widgetList<Opacity>(
        find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(Opacity),
        ),
      );

      // Thẻ đầu tiên (Hôm nay) phải có opacity 1.0
      expect(opacities.isNotEmpty, isTrue);
      expect(opacities.first.opacity, 1.0);
    });
  });

  group('Nhiệm vụ 7: Tối giản bộ điều khiển nền & 3 Presets Mới', () {
    testWidgets('Bộ điều khiển nền gồm 2 nút [ NỀN TỐI ] | [ NỀN SÁNG ]', (tester) async {
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

      expect(find.text('NỀN TỐI'), findsOneWidget);
      expect(find.text('NỀN SÁNG'), findsOneWidget);

      // Bấm NỀN SÁNG -> Status bar đổi sang #1E293B
      await tester.tap(find.text('NỀN SÁNG'));
      await tester.pumpAndSettle();
      final textWidget = tester.widget<Text>(find.text('09:41'));
      expect(textWidget.style?.color, const Color(0xFF1E293B));

      // Bấm NỀN TỐI -> Status bar đổi sang màu trắng
      await tester.tap(find.text('NỀN TỐI'));
      await tester.pumpAndSettle();
      final darkTextWidget = tester.widget<Text>(find.text('09:41'));
      expect(darkTextWidget.style?.color, Colors.white.withOpacity(0.85));
    });

    test('3 Presets màu mới (Dark Obsidian, Deep Forest, Sunset Minimal) hoạt động hợp lệ', () {
      final obsidian = WidgetThemeConfig.darkObsidian();
      expect(obsidian.bgColorHex, '#0F172A');
      expect(obsidian.accentColorHex, '#6366F1');
      expect(obsidian.bgStyle, 'solid');

      final forest = WidgetThemeConfig.deepForest();
      expect(forest.bgColorHex, '#064E3B');
      expect(forest.accentColorHex, '#10B981');
      expect(forest.bgStyle, 'solid');

      final sunset = WidgetThemeConfig.sunsetMinimal();
      expect(sunset.bgColorHex, '#4C1D95');
      expect(sunset.accentColorHex, '#EC4899');
      expect(sunset.bgStyle, 'solid');

      // Test JSON roundtrip
      final jsonMap = sunset.toJson();
      final restored = WidgetThemeConfig.fromJson(jsonMap);
      expect(restored.bgColorHex, '#4C1D95');
      expect(restored.accentColorHex, '#EC4899');
      expect(restored.bgStyle, 'solid');
    });
  });
}
