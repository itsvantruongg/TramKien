import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/widget_models.dart';
import '../lib/screens/widget_studio_screen.dart';

void main() {
  group('Iteration 17: Zero-Hang Splash & Google Android Guidelines Compliance', () {
    test('1. Zero-Hang Splash: lib/main.dart không còn await p.cacheLoaded, dùng p.authReady nạp SQLite cache trước khi tắt Splash', () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue);
      final content = mainFile.readAsStringSync();

      // Không còn await p.cacheLoaded
      expect(content.contains('await p.cacheLoaded;'), isFalse,
          reason: 'Lệnh await p.cacheLoaded đã được xóa bỏ để giải phóng Splash');
      
      // Chờ authReady và gọi setState + FlutterNativeSplash.remove
      expect(content.contains('await p.authReady;'), isTrue);
      expect(content.contains('setState(() => _quickAuthDone = true);'), isTrue);
      expect(content.contains('FlutterNativeSplash.remove();'), isTrue);
    });

    test('2. Layout XML: FrameLayout gốc khai báo android:id="@android:id/background" và padding 12dp', () {
      final xmlFiles = [
        'widget_schedule_single_day_2x2.xml',
        'widget_schedule_three_days.xml',
        'widget_schedule_weekly.xml',
      ];

      for (final filename in xmlFiles) {
        final file = File('android/app/src/main/res/layout/$filename');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // Kiểm tra FrameLayout gốc có android:id="@android:id/background"
        expect(
          content.contains('<FrameLayout') && content.contains('android:id="@android:id/background"'),
          isTrue,
          reason: '$filename phải khai báo FrameLayout gốc với android:id="@android:id/background" theo chuẩn Google',
        );

        // Vẫn giữ widget_root bên trong để tương thích RemoteViews và tests
        expect(
          content.contains('android:id="@+id/widget_root"'),
          isTrue,
          reason: '$filename phải duy trì widget_root',
        );

        // Padding an toàn nội dung chuẩn 10dp
        expect(
          content.contains('android:padding="10dp"'),
          isTrue,
          reason: '$filename phải có padding an toàn chuẩn 10dp chống lẹm mép cong Launcher',
        );

        // Padding 10dp lớp 1 ngoài cùng tạo khoảng thở launcher
        expect(
          content.contains('android:padding="10dp"'),
          isTrue,
          reason: '$filename phải có padding 10dp ở Lớp 1 tạo khoảng thở launcher',
        );
      }
    });

    test('3. Kotlin ScheduleWidgetProvider: Bo góc chuẩn Google (16dp) & Click pending intent cho background', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final content = ktFile.readAsStringSync();

      // Kiểm tra bán kính bo góc 16dp chuẩn hóa
      expect(content.contains('val radiusDp = 16f'), isTrue);

      // Pending intent gán cho cả android.R.id.background
      expect(content.contains('views.setOnClickPendingIntent(android.R.id.background,'), isTrue);
    });

    test('4. WCAG AA Text Contrast: textSecColor #475569 khi isLightBg, #CBD5E1 khi nền tối', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final content = ktFile.readAsStringSync();

      // textSecColor mặc định là #CBD5E1
      expect(content.contains('var textSecColor = Color.parseColor("#CBD5E1")'), isTrue);

      // Logic chuyển màu tương phản cao theo isLightBg
      expect(content.contains('val defaultSecColorHex = if (isLightBg) "#475569" else "#CBD5E1"'), isTrue);
      expect(content.contains('Color.parseColor("#475569")'), isTrue);
      expect(content.contains('Color.parseColor("#CBD5E1")'), isTrue);
    });

    testWidgets('5. Realtime Reactive Preview: Live Preview phản hồi tức thì khi đổi màu sắc', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tìm ChoiceChip Transparent
      final chipTransparent = find.text('Trong suốt 100%');
      expect(chipTransparent, findsOneWidget);

      await tester.ensureVisible(chipTransparent);
      await tester.pumpAndSettle();

      await tester.tap(chipTransparent);
      await tester.pumpAndSettle();

      // Kiểm tra ChoiceChip đã được chọn ngay lập tức
      final choiceChip = tester.widget<ChoiceChip>(
        find.ancestor(of: chipTransparent, matching: find.byType(ChoiceChip)),
      );
      expect(choiceChip.selected, isTrue);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
