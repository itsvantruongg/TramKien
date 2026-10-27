import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/widget_models.dart';
import '../lib/screens/widget_studio_screen.dart';

void main() {
  group('Iteration 18: Startup Lifecycle & Zero-Flicker Dashboard (Task 1)', () {
    test('1.1 lib/main.dart khôi phục await p.authReady nạp SQLite cache lên RAM trước khi tắt Splash', () {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('await p.authReady;'), isTrue,
          reason: 'main.dart phải chờ p.authReady để nạp 100% SQLite cache lên RAM trong lúc Splash đang giữ');
      expect(content.contains('FlutterNativeSplash.remove();'), isTrue);
    });

    test('1.2 lib/providers/app_provider.dart bật sẵn cờ _isSyncing = true trước khi gán AuthState.loggedIn', () {
      final file = File('lib/providers/app_provider.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final loginIdx = content.indexOf('Future<bool> login(');
      expect(loginIdx, isNot(-1));
      final loginBlock = content.substring(loginIdx, loginIdx + 2500);

      final syncingIdx = loginBlock.indexOf('_isSyncing = true;');
      final loggedInIdx = loginBlock.indexOf('_authState = AuthState.loggedIn;');
      expect(syncingIdx, isNot(-1), reason: '_isSyncing = true phải được gán trong login()');
      expect(loggedInIdx, isNot(-1), reason: '_authState = AuthState.loggedIn phải được gán trong login()');
      expect(syncingIdx < loggedInIdx, isTrue,
          reason: '_isSyncing = true phải được bật TRƯỚC _authState = AuthState.loggedIn để Dashboard hiển thị Skeleton từ Frame 0');
    });
  });

  group('Iteration 18: Triệt tiêu chớp nháy 2 lần trong Widget Studio (Task 2)', () {
    test('2.1 WidgetStudioScreen sử dụng AnimatedSwitcher 150ms và FadeTransition cho Preview Card', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('AnimatedSwitcher('), isTrue);
      expect(content.contains('Duration(milliseconds: 150)'), isTrue);
      expect(content.contains('FadeTransition('), isTrue);
    });

    testWidgets('2.2 WidgetStudioScreen render mượt mà AnimatedSwitcher khi mở màn hình', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.frostedGlass(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsWidgets);
      expect(find.byKey(const ValueKey('flutter_fallback_card')), findsOneWidget);
    });
  });

  group('Iteration 18 & 19: Cấu trúc lấp đầy chuẩn tăm tắp trong Lịch tuần 4x4 (Task 3)', () {
    test('3.1 widget_schedule_weekly.xml khai báo maxLines="1" cho grid_cell_name_1 đến 7', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      for (int i = 1; i <= 7; i++) {
        final cellBlock = RegExp('<TextView\\b[^>]*?grid_cell_name_$i[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(cellBlock.contains('android:maxLines="1"'), isTrue,
            reason: 'grid_cell_name_$i phải có android:maxLines="1" để hàng 2 tăm tắp');
        expect(cellBlock.contains('android:textSize="10.5sp"') || cellBlock.contains('android:textSize="10sp"'), isTrue);
      }
    });

    test('3.2 ScheduleWidgetProvider.kt triển khai cấu trúc chuẩn: Hàng 2 (Môn 1), Hàng 3 (Giờ/Phòng), Môn 2 và (+N môn nữa)', () {
      final file = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra Hàng 2 gán c1Title và Hàng 3 gán c1TimeRoom
      expect(content.contains('views.setTextViewText(nameIds[i], c1Title)'), isTrue);
      expect(content.contains('views.setTextViewText(hybridIds[i], c1TimeRoom)'), isTrue);

      // Kiểm tra Hàng 4: 1 môn ẩn, 2 môn hiện Môn 2, >= 3 môn hiện (+remaining môn nữa)
      expect(content.contains('views.setViewVisibility(subIds[i], View.GONE)'), isTrue);
      expect(content.contains('c2Title') || content.contains('formatCourseSummary(c2)'), isTrue);
      expect(content.contains('val remaining = count - 2') || content.contains('val remaining = count - 1'), isTrue);
      expect(content.contains(r'views.setTextViewText(subIds[i], "(+$remaining môn nữa)")'), isTrue);
    });

    test('3.3 WidgetStudioScreen._buildGridDayCell đồng bộ 100% cấu trúc 5-6 dòng lấp đầy', () {
      final file = File('lib/screens/widget_studio_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra cấu trúc trong _buildGridDayCell
      expect(content.contains("'(+\${count - 2} môn nữa)'") || content.contains("'(+\${count - 1} môn nữa)'"), isTrue,
          reason: 'Studio preview phải hiển thị (+... môn nữa) cho ngày >= 3 môn tương ứng Native');
      expect(content.contains('classes[1]'), isTrue,
          reason: 'Studio preview phải hiển thị môn 2 cho ngày có >= 2 môn');
    });
  });
}
