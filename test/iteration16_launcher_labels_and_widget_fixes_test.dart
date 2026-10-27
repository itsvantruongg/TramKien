import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nhiệm vụ 1: Tối giản 100% nhãn widget launcher (xóa bỏ "Trạm Kiến • ")', () {
    final manifestFile = File('android/app/src/main/AndroidManifest.xml');

    test('AndroidManifest.xml tồn tại và chứa đúng các nhãn widget sạch không bị cắt cụt', () {
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      // 3 Widget tinh hoa (SPEC-WIDGET-CLEANUP-2X2: SingleDayScheduleWidgetProvider 4x2 thay cho 2x2)
      expect(content.contains('android:name=".SingleDayScheduleWidgetProvider"'), isTrue);
      expect(
        content.contains('android:label="Lịch hôm nay (4x2 Timeline)"') ||
        content.contains('android:label="Lịch hôm nay"'),
        isTrue,
      );

      expect(content.contains('android:name=".ThreeDaysScheduleWidgetProvider"'), isTrue);
      expect(content.contains('android:label="Lịch 3 ngày"'), isTrue);

      expect(content.contains('android:name=".WeeklyScheduleWidgetProvider"'), isTrue);
      expect(content.contains('android:label="Lịch tuần"'), isTrue);

      // Tuyệt đối không còn tiền tố dài dòng "Trạm Kiến • " làm cắt cụt tên trong Widget Picker
      expect(content.contains('android:label="Trạm Kiến • '), isFalse);
    });
  });

  group('Nhiệm vụ 2: Sửa triệt để luồng Áp dụng -> Add automatically', () {
    final receiverFile = File('android/app/src/main/kotlin/com/tramkien/hau/WidgetPinSuccessReceiver.kt');
    final mainActivityFile = File('android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt');
    final manifestFile = File('android/app/src/main/AndroidManifest.xml');

    test('WidgetPinSuccessReceiver tồn tại và gửi broadcast cập nhật, không ép CATEGORY_HOME', () {
      expect(receiverFile.existsSync(), isTrue);
      final content = receiverFile.readAsStringSync();

      expect(content.contains('class WidgetPinSuccessReceiver : BroadcastReceiver()'), isTrue);
      expect(content.contains('com.tramkien.hau.ACTION_UPDATE_WIDGET'), isTrue);
      expect(content.contains('context.sendBroadcast'), isTrue);
      expect(content.contains('addCategory(Intent.CATEGORY_HOME)'), isFalse);
      expect(content.contains('context.startActivity'), isFalse);
    });

    test('WidgetPinSuccessReceiver được đăng ký trong AndroidManifest.xml', () {
      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:name=".WidgetPinSuccessReceiver"'), isTrue);
      expect(content.contains('android:name="com.tramkien.hau.ACTION_PIN_WIDGET_SUCCESS"'), isTrue);
    });

    test('MainActivity sử dụng WidgetPinSuccessReceiver làm successCallback trong requestPinAppWidget', () {
      final content = mainActivityFile.readAsStringSync();
      expect(content.contains('WidgetPinSuccessReceiver::class.java'), isTrue);
      expect(content.contains('com.tramkien.hau.ACTION_PIN_WIDGET_SUCCESS'), isTrue);
      expect(content.contains('appWidgetManager.requestPinAppWidget('), isTrue);
    });
  });

  group('Nhiệm vụ 3: Sửa lỗi cắt cụt chữ & Tối ưu không gian 3 Layout XML', () {
    test('widget_schedule_weekly.xml có font 9sp cho header, 10sp maxLines=1 cho tên môn (chuẩn 4 hàng), 8.5sp cho hybrid và 11sp cho tổng kết', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_weekly.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Kiểm tra 7 ô ngày
      for (int i = 1; i <= 7; i++) {
        expect(content.contains('android:id="@+id/grid_cell_header_$i"'), isTrue);
        expect(content.contains('android:id="@+id/grid_cell_name_$i"'), isTrue);
        expect(content.contains('android:id="@+id/grid_cell_hybrid_$i"'), isTrue);
      }

      // Tên môn phải có maxLines="1" theo chuẩn 4 hàng tăm tắp
      final name1Block = RegExp(r'<TextView\b[^>]*?grid_cell_name_1[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(name1Block.contains('android:maxLines="1"'), isTrue);
      expect(name1Block.contains('android:textSize="10.5sp"') || name1Block.contains('android:textSize="10sp"'), isTrue);

      final hybrid1Block = RegExp(r'<TextView\b[^>]*?grid_cell_hybrid_1[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(hybrid1Block.contains('android:textSize="9sp"') || hybrid1Block.contains('android:textSize="8.5sp"'), isTrue);

      // Ô tổng kết tuần (Ô 8)
      final sumTitle = RegExp(r'<TextView\b[^>]*?grid_cell_summary_title[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(sumTitle.contains('android:textSize="10sp"') || sumTitle.contains('android:textSize="9sp"'), isTrue);

      final sumClasses = RegExp(r'<TextView\b[^>]*?grid_cell_summary_classes[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(sumClasses.contains('android:textSize="12sp"') || sumClasses.contains('android:textSize="11sp"'), isTrue);

      final sumEmpty = RegExp(r'<TextView\b[^>]*?grid_cell_summary_empty_days[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(sumEmpty.contains('android:textSize="10sp"') || sumEmpty.contains('android:textSize="9sp"'), isTrue);
    });

    test('widget_schedule_three_days.xml nâng cỡ chữ: date prefix 10sp, class name 11sp, hybrid 9sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_three_days.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      for (int i = 1; i <= 3; i++) {
        final prefixBlock = RegExp('<TextView\\b[^>]*?day_${i}_date_prefix[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(prefixBlock.contains('android:textSize="10sp"'), isTrue);

        final nameBlock = RegExp('<TextView\\b[^>]*?day_${i}_class_name[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(nameBlock.contains('android:textSize="11sp"'), isTrue);

        final hybridBlock = RegExp('<TextView\\b[^>]*?day_${i}_class_hybrid[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
        expect(hybridBlock.contains('android:textSize="9sp"'), isTrue);
      }
    });

    test('widget_schedule_single_day_2x2.xml có class name 11.5sp, hybrid 9sp, footer badge 9sp', () {
      final file = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final name1Block = RegExp(r'<TextView\b[^>]*?single_2x2_class_1_name[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(name1Block.contains('android:textSize="11.5sp"'), isTrue);

      final hybrid1Block = RegExp(r'<TextView\b[^>]*?single_2x2_class_1_hybrid[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(hybrid1Block.contains('android:textSize="9sp"'), isTrue);

      final badgeBlock = RegExp(r'<TextView\b[^>]*?single_2x2_badge[^>]*?/>', dotAll: true).firstMatch(content)?.group(0) ?? '';
      expect(badgeBlock.contains('android:textSize="9sp"'), isTrue);
    });
  });

  group('Nhiệm vụ 4: Cập nhật khoảng cách, dữ liệu đồng bộ và format [THI] #EF4444', () {
    final kotlinFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');

    test('ScheduleWidgetProvider.kt tách riêng Tên môn và Giờ • Phòng khi có 1 ca học', () {
      final content = kotlinFile.readAsStringSync();
      expect(content.contains('fun formatCourseTimeRoom('), isTrue);
      expect(content.contains('fun formatCourseTitle('), isTrue);
      expect(content.contains('fun isCourseExam('), isTrue);
      expect(content.contains('#EF4444'), isTrue);
    });
  });
}
