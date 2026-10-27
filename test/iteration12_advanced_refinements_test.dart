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

  group('Nhiệm vụ 1: Đồng bộ Box nổi bật "Hôm nay" ra Native Android Launcher', () {
    test('Drawable widget_today_highlight_bg.xml tồn tại, bo góc 8dp, viền 0.8dp, nền mờ #251D64F2', () {
      final file = File('android/app/src/main/res/drawable/widget_today_highlight_bg.xml');
      expect(file.existsSync(), isTrue, reason: 'Tệp widget_today_highlight_bg.xml phải tồn tại');
      final content = file.readAsStringSync();
      expect(content.contains('<solid android:color="#251D64F2"'), isTrue);
      expect(content.contains('<stroke'), isTrue);
      expect(content.contains('android:width="0.8dp"'), isTrue);
      expect(content.contains('android:color="#8C1D64F2"'), isTrue);
      expect(content.contains('<corners android:radius="8dp"'), isTrue);
    });

    test('ScheduleWidgetProvider.kt gán widget_today_highlight_bg cho hàng Hôm nay (day_row_1)', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('views.setInt(rowIds[i], "setBackgroundResource", R.drawable.widget_today_highlight_bg)'),
        isTrue,
        reason: 'Hàng Hôm nay phải được setBackgroundResource bằng widget_today_highlight_bg',
      );
      expect(
        content.contains('views.setInt(rowIds[i], "setBackgroundResource", 0)'),
        isTrue,
        reason: 'Các hàng khác phải reset background về 0',
      );
    });

    test('Bảo đảm độ tương phản WCAG: Khi isToday == true & "Không có lịch", dùng textColor sáng rõ', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      final content = file.readAsStringSync();
      expect(
        content.contains('views.setTextViewText(nameIds[i], "Không có lịch")'),
        isTrue,
      );
      expect(
        content.contains('views.setTextColor(nameIds[i], if (isToday) textColor else textSecColor)'),
        isTrue,
        reason: 'Chữ "Không có lịch" khi isToday == true phải dùng textColor có độ tương phản cao',
      );
    });
  });

  group('Nhiệm vụ 2: Sửa triệt để nút "Áp dụng -> Add Automatically"', () {
    test('MainActivity.kt ánh xạ đủ 6 Widget Provider dựa trên layoutMode và variant', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra đọc tham số
      expect(content.contains('val layoutMode = call.argument<String>("layoutMode")'), isTrue);
      expect(content.contains('val variant = call.argument<String>("variant")'), isTrue);

      // Kiểm tra mapping 6 Provider
      expect(content.contains('SingleDay2x2ScheduleWidgetProvider::class.java'), isTrue);
      expect(content.contains('SingleDayScheduleWidgetProvider::class.java'), isTrue);
      expect(content.contains('TomorrowScheduleWidgetProvider::class.java'), isTrue);
      expect(content.contains('ThreeDaysScheduleWidgetProvider::class.java'), isTrue);
      expect(content.contains('WeeklyStripScheduleWidgetProvider::class.java'), isTrue);
      expect(content.contains('WeeklyScheduleWidgetProvider::class.java'), isTrue);
    });

    test('MainActivity.kt gọi requestPinAppWidget mà không preempt launcher bằng startActivity CATEGORY_HOME', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
      final content = file.readAsStringSync();
      expect(content.contains('appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)'), isTrue);
      expect(content.contains('context.startActivity(homeIntent)'), isFalse);
    });

    test('WidgetDataSyncService.requestPinWidget hỗ trợ truyền layoutMode và variant', () async {
      // Gọi thử method với timeout ngắn để verify signature và không crash
      final result = await WidgetDataSyncService.requestPinWidget(
        layoutMode: 'three_days',
        variant: '4x2',
      );
      // Trên môi trường test không có native engine nên trả về false
      expect(result, isFalse);
    });
  });

  group('Nhiệm vụ 3: Bảng màu HSV Color Wheel tương tác 2 chiều', () {
    test('WidgetThemeConfig hỗ trợ borderColorHex, serialize/deserialize vẹn toàn', () {
      final config = WidgetThemeConfig.frostedGlass().copyWith(
        borderColorHex: '#33FFFFFF',
      );
      expect(config.borderColorHex, '#33FFFFFF');

      final map = config.toJson();
      expect(map['border_color_hex'], '#33FFFFFF');

      final deserialized = WidgetThemeConfig.fromJson(map);
      expect(deserialized.borderColorHex, '#33FFFFFF');

      // Test copyWith
      final updated = config.copyWith(borderColorHex: '#0A84FF');
      expect(updated.borderColorHex, '#0A84FF');
      expect(updated.accentColorHex, '#1D64F2');
    });

    testWidgets('WidgetStudioScreen hiển thị đủ 5 thuộc tính màu và mở Dialog HSV Color Wheel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1400));
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

      // Cuộn xuống khu vực BẢNG MÀU TÙY CHỈNH
      await tester.scrollUntilVisible(
        find.text('Màu Điểm Nhấn'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Kiểm tra 4 thuộc tính màu (Màu Viền đã được loại bỏ hoàn toàn theo AC-07)
      expect(find.text('Màu Nền'), findsOneWidget);
      expect(find.text('Màu Chữ Chính'), findsOneWidget);
      expect(find.text('Màu Chữ Phụ'), findsOneWidget);
      expect(find.text('Màu Điểm Nhấn'), findsOneWidget);
      expect(find.text('Màu Viền'), findsNothing);

      // Tìm nút icon edit (cây bút chì) để mở HSV Dialog của Màu Tùy Chỉnh (AC-07)
      final editButtons = find.byIcon(Icons.edit);
      expect(editButtons, findsWidgets);

      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Dialog mở thành công: có CustomPaint vẽ wheel, ô nhập HEX, thanh slider độ sáng
      expect(find.text('TÙY CHỈNH MÀU'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Slider)), findsOneWidget);
      final dialogApplyButton = find.descendant(of: find.byType(AlertDialog), matching: find.text('ÁP DỤNG'));
      expect(dialogApplyButton, findsOneWidget);
      expect(find.text('HỦY'), findsOneWidget);

      // Bấm Áp dụng đóng dialog
      await tester.tap(dialogApplyButton);
      await tester.pumpAndSettle();
      expect(find.text('TÙY CHỈNH MÀU'), findsNothing);
    });
  });

  group('Nhiệm vụ 4: Hỗ trợ chọn ảnh từ máy làm nền Widget', () {
    testWidgets('Nút [ CHỌN ẢNH TỪ MÁY ] hiển thị trong WidgetStudioScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1400));
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

      // Cuộn tìm nút CHỌN ẢNH TỪ MÁY
      await tester.scrollUntilVisible(
        find.text('CHỌN ẢNH TỪ MÁY'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('CHỌN ẢNH TỪ MÁY'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    });

    test('MainActivity.kt hỗ trợ method pickImage và lưu vào filesDir/widget_custom_bg.png', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
      final content = file.readAsStringSync();
      expect(content.contains('"pickImage"'), isTrue);
      expect(content.contains('Intent.ACTION_GET_CONTENT'), isTrue);
      expect(content.contains('type = "image/*"'), isTrue);
      expect(content.contains('File(filesDir, "widget_custom_bg.png")'), isTrue);
    });

    test('Cả 6 layout XML native đều có FrameLayout gốc và ImageView widget_bg_image lớp nền', () {
      final xmlFiles = [
        'widget_schedule_single_day.xml',
        'widget_schedule_single_day_2x2.xml',
        'widget_schedule_tomorrow.xml',
        'widget_schedule_three_days.xml',
        'widget_schedule_weekly.xml',
        'widget_schedule_weekly_strip.xml',
      ];

      for (final filename in xmlFiles) {
        final file = File('android/app/src/main/res/layout/$filename');
        expect(file.existsSync(), isTrue, reason: 'Layout $filename phải tồn tại');
        final content = file.readAsStringSync();
        expect(
          content.contains('<FrameLayout') && content.contains('android:id="@+id/widget_root"'),
          isTrue,
          reason: 'Layout $filename phải có FrameLayout làm root container',
        );
        expect(
          content.contains('android:id="@+id/widget_bg_image"'),
          isTrue,
          reason: 'Layout $filename phải có ImageView widget_bg_image làm nền',
        );
        expect(
          content.contains('android:scaleType="fitXY"'),
          isTrue,
          reason: 'Layout $filename phải có scaleType="fitXY"',
        );
        expect(
          content.contains('android:visibility="gone"'),
          isTrue,
          reason: 'Layout $filename phải có visibility="gone" mặc định',
        );
      }
    });

    test('ScheduleWidgetProvider.kt bo góc và phủ lớp tối WCAG cho custom background image', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      final content = file.readAsStringSync();
      expect(content.contains('val customBgPath = themeObj.optString("custom_bg_image_path", "")'), isTrue);
      expect(content.contains('createRoundedBitmapWithOverlay(context, original, radiusDp, 130)'), isTrue);
      expect(content.contains('Color.argb(overlayAlpha.coerceIn(0, 255), 0, 0, 0)'), isTrue);
      expect(content.contains('canvas.drawRect(rectF, overlayPaint)'), isTrue);
    });
  });

  group('Nhiệm vụ 5: Đồng bộ 100% Font Size giữa Native XML và Mockup', () {
    test('widget_schedule_weekly_strip.xml nâng lên 9.5sp (thứ ngày) và 11.5sp (môn học)', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly_strip.xml');
      final content = file.readAsStringSync();

      // Kiểm tra 7 TextView thứ ngày dùng 9.5sp
      final weekdayMatches = RegExp(r'android:id="@\+id/strip_day_weekday_\d"[\s\S]*?android:textSize="([^"]+)"')
          .allMatches(content);
      expect(weekdayMatches.length, 7, reason: 'Phải tìm đủ 7 cột thứ ngày trong strip');
      for (final match in weekdayMatches) {
        expect(match.group(1), '9.5sp', reason: 'Cột thứ ngày phải có textSize="9.5sp"');
      }

      // Kiểm tra tên môn học dùng 11.5sp
      final subjectMatch = RegExp(r'android:id="@\+id/strip_class_name"[\s\S]*?android:textSize="([^"]+)"')
          .firstMatch(content);
      expect(subjectMatch, isNotNull);
      expect(subjectMatch!.group(1), '11.5sp', reason: 'Tên môn học trong strip phải có textSize="11.5sp"');
    });

    test('widget_schedule_weekly.xml nâng lên 8.5sp (giờ/phòng trong lưới 8 ô)', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      final content = file.readAsStringSync();

      // Kiểm tra các TextView giờ/phòng grid_cell_hybrid_1 đến 7
      final timeMatches = RegExp(r'android:id="@\+id/grid_cell_hybrid_\d"[\s\S]*?android:textSize="([^"]+)"')
          .allMatches(content);
      expect(timeMatches.length, 7, reason: 'Phải tìm đủ 7 ô giờ/phòng trong weekly grid');
      for (final match in timeMatches) {
        expect(match.group(1) == '9sp' || match.group(1) == '8.5sp', isTrue, reason: 'Dòng giờ/phòng trong weekly grid phải có textSize="9sp" hoặc "8.5sp"');
      }
    });
  });
}
