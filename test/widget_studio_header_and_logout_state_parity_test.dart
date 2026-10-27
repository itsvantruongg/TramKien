import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  group('SPEC-WIDGET-STUDIO-HEADER-AND-LOGOUT-STATE-PARITY-01 Tests', () {
    testWidgets('AC-01: Header Widget Studio có leading back button, titleSpacing 0 và bảng màu chuẩn', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(AppTheme.surface));
      expect(appBar.titleSpacing, equals(0));
      expect(appBar.leading, isNotNull);

      final titleText = tester.widget<Text>(find.text('WIDGET STUDIO'));
      expect(titleText.style?.color, equals(AppTheme.primary));
      expect(titleText.style?.fontFamily, equals('Manrope'));
      expect(titleText.style?.fontSize, equals(16));
      expect(titleText.style?.fontWeight, equals(FontWeight.w800));
      expect(titleText.style?.letterSpacing, equals(1.2));

      final subtitleText = tester.widget<Text>(find.text('XƯỞNG TÙY BIẾN THỜI KHÓA BIỂU THỤY SĨ'));
      expect(subtitleText.style?.color, equals(AppTheme.outline));
      expect(subtitleText.style?.fontFamily, equals('Inter'));
      expect(subtitleText.style?.fontSize, equals(10));
      expect(subtitleText.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets('AC-02: Loại bỏ 100% emoji, thay thế bằng Icon Vector lightbulb_outline_rounded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Cuộn tới phần hướng dẫn dưới cùng
      final textFinder = find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến');
      await tester.scrollUntilVisible(textFinder, 300, scrollable: find.byType(Scrollable).first);

      expect(textFinder, findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

      // Đảm bảo không còn chuỗi emoji 💡
      expect(find.textContaining('💡'), findsNothing);

      // Kiểm tra trong mã nguồn Dart cũng không còn emoji 💡
      final dartSource = File('lib/screens/widget_studio_screen.dart').readAsStringSync();
      expect(dartSource.contains('💡'), isFalse, reason: 'Zero emoji allowed in widget_studio_screen.dart');
    });

    test('AC-03: Android ScheduleWidgetProvider.kt ẩn single_day_content và hiển thị thông báo đăng nhập khi logout', () {
      final kotlinSource = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt').readAsStringSync();

      expect(kotlinSource.contains('"single_day" -> {'), isTrue);
      expect(kotlinSource.contains('views.setViewVisibility(R.id.single_day_content, View.GONE)'), isTrue);
      expect(kotlinSource.contains('views.setTextViewText(R.id.class_empty_message, "Trạm Kiến • Vui lòng đăng nhập")'), isTrue);
      expect(kotlinSource.contains('views.setTextColor(R.id.class_empty_message, textSecColor)'), isTrue);
      expect(kotlinSource.contains('views.setViewVisibility(R.id.class_empty_message, View.VISIBLE)'), isTrue);
    });

    test('AC-04: iOS ScheduleWidgetKit.swift hiển thị Trạm Kiến • Vui lòng đăng nhập khi chưa đăng nhập', () {
      final swiftSource = File('ios/Runner/ScheduleWidgetKit.swift').readAsStringSync();

      expect(swiftSource.contains('let isLoggedIn = (scheduleData != nil && !days.isEmpty)'), isTrue);
      expect(swiftSource.contains('Text("Trạm Kiến • Vui lòng đăng nhập")'), isTrue);
      expect(swiftSource.contains('widgetTitle = "Trạm Kiến"'), isTrue);
      expect(swiftSource.contains('if !entry.isLoggedIn'), isTrue);
    });
  });
}
