import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SPEC-WIDGET-ENHANCEMENT-01 Acceptance Criteria Verification Tests', () {
    test('AC-01: Tối Ưu Bố Cục Thẻ 2x2 Android & Triệt Tiêu Khoảng Trống Chết', () {
      final xmlFile = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      expect(xmlFile.existsSync(), isTrue, reason: 'widget_schedule_single_day_2x2.xml must exist');
      final content = xmlFile.readAsStringSync();

      // 1. widget_content_container và single_2x2_content có gravity="top"
      final containerMatch = RegExp(r'<LinearLayout\b[^>]*?android:id="@\+id/widget_content_container"[^>]*?>', dotAll: true).firstMatch(content);
      expect(containerMatch, isNotNull);
      expect(containerMatch!.group(0)!.contains('android:gravity="top"'), isTrue,
          reason: 'widget_content_container must have android:gravity="top"');

      final contentMatch = RegExp(r'<LinearLayout\b[^>]*?android:id="@\+id/single_2x2_content"[^>]*?>', dotAll: true).firstMatch(content);
      expect(contentMatch, isNotNull);
      expect(contentMatch!.group(0)!.contains('android:gravity="top"'), isTrue,
          reason: 'single_2x2_content must have android:gravity="top"');

      // 2. Không còn single_2x2_top_spacer
      expect(content.contains('single_2x2_top_spacer'), isFalse,
          reason: 'single_2x2_top_spacer must be eliminated');

      // 3. Không còn spacer thứ hai layout_weight="1"
      final matchesWeights = RegExp(r'android:layout_weight="1"').allMatches(content);
      // Chỉ còn widget_content_container có layout_weight="1" (và widget_title có layout_weight="1")
      for (final m in matchesWeights) {
        final preContext = content.substring((m.start - 100).clamp(0, content.length), m.start);
        expect(preContext.contains('<ImageView'), isFalse,
            reason: 'No ImageView spacers with layout_weight="1" allowed in 2x2 content');
      }

      // 4. Môn 2 có marginTop="6dp"
      final c2Container = RegExp(r'<LinearLayout\b[^>]*?android:id="@\+id/single_2x2_class_2_container"[^>]*?>', dotAll: true).firstMatch(content);
      expect(c2Container, isNotNull);
      expect(c2Container!.group(0)!.contains('android:layout_marginTop="6dp"'), isTrue);

      // 5. Badge có marginTop="6dp"
      final badgeMatch = RegExp(r'<TextView\b[^>]*?android:id="@\+id/single_2x2_badge"[^>]*?>', dotAll: true).firstMatch(content);
      expect(badgeMatch, isNotNull);
      expect(badgeMatch!.group(0)!.contains('android:layout_marginTop="6dp"'), isTrue);

      // 6. Live preview trong lib/screens/widget_studio_screen.dart đồng bộ top-alignment
      final studioFile = File('lib/screens/widget_studio_screen.dart');
      expect(studioFile.existsSync(), isTrue);
      final studioContent = studioFile.readAsStringSync();
      expect(studioContent.contains('_buildSingleDay2x2Content'), isTrue);
      expect(studioContent.contains('mainAxisAlignment: MainAxisAlignment.start'), isTrue);
    });

    test('AC-02: Cơ Chế Co Giãn Động Cho Cả 3 Dạng Widget (Responsive Launcher Resize)', () {
      final ktFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final ktContent = ktFile.readAsStringSync();

      // 1. Kiểm tra lắng nghe Launcher Resize
      expect(ktContent.contains('val isWideLauncher = minWidthDp >= 220 || (widthPx > 0 && widthPx >= 550)'), isTrue);
      expect(ktContent.contains('val isTallLauncher = minHeightDp >= 200 || (heightPx > 0 && heightPx >= 500)'), isTrue);

      // 2. Thẻ 1 Ngày (2x2):
      // - Bung rộng thông tin Giờ • Phòng • Giảng viên • Mã lớp
      expect(ktContent.contains('fun formatCourseTimeRoom(c: JSONObject, isWide: Boolean = false): String'), isTrue);
      expect(ktContent.contains('val classCodeStr = if (isWide && showClassCode) c.optString("class_code", "") else ""'), isTrue);
      // - Luôn giữ đúng 2 dòng duy nhất (maxLines = 1) khi kéo rộng (SPEC-TIMELINE-WIDGET-02)
      expect(ktContent.contains('views.setInt(R.id.single_2x2_class_1_hybrid, "setMaxLines", 1)'), isTrue);

      // - Unhide môn 3, 4 khi kéo cao
      expect(ktContent.contains('R.id.single_2x2_class_3_container'), isTrue);
      expect(ktContent.contains('R.id.single_2x2_class_4_container'), isTrue);

      final xml2x2File = File('android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml');
      final xml2x2Content = xml2x2File.readAsStringSync();
      expect(xml2x2Content.contains('android:id="@+id/single_2x2_class_3_container"'), isTrue);
      expect(xml2x2Content.contains('android:id="@+id/single_2x2_class_4_container"'), isTrue);

      // 3. Thẻ Lịch 3 Ngày:
      // - Khi minHeightDp >= 200dp: hiển thị cả Môn 1 và Môn 2 chi tiết
      expect(ktContent.contains('R.id.day_1_class_extra'), isTrue);
      expect(ktContent.contains('R.id.day_2_class_extra'), isTrue);
      expect(ktContent.contains('R.id.day_3_class_extra'), isTrue);

      final xml3DaysFile = File('android/app/src/main/res/layout/widget_schedule_three_days.xml');
      final xml3DaysContent = xml3DaysFile.readAsStringSync();
      expect(xml3DaysContent.contains('android:id="@+id/day_1_class_extra"'), isTrue);
      expect(xml3DaysContent.contains('android:id="@+id/day_2_class_extra"'), isTrue);
      expect(xml3DaysContent.contains('android:id="@+id/day_3_class_extra"'), isTrue);

      // 4. Thẻ Lịch Tuần (4x4):
      // - maxLines="1" khóa cứng 1 dòng duy nhất, text dài cắt bằng dấu ba chấm "..."
      expect(ktContent.contains('val weeklyNameMaxLines = 1'), isTrue);
      expect(ktContent.contains('views.setInt(nameIds[i], "setMaxLines", weeklyNameMaxLines)'), isTrue);
    });

    test('AC-03: Đồng Bộ Hiển Thị Giảng Viên Trên WidgetKit iOS', () {
      final swiftFile = File('ios/Runner/ScheduleWidgetKit.swift');
      expect(swiftFile.existsSync(), isTrue, reason: 'ScheduleWidgetKit.swift must exist');
      final swiftContent = swiftFile.readAsStringSync();

      // 1. Entry model chứa showTeacher
      expect(swiftContent.contains('let showTeacher: Bool'), isTrue);

      // 2. Timeline provider loadData map showTeacher từ themeConfig
      expect(swiftContent.contains('showTeacher: themeConfig?.showTeacher ?? false'), isTrue);

      // 3. .systemSmall hiển thị teacher khi showTeacher bật
      expect(swiftContent.contains('(entry.showTeacher && !c.teacher.isEmpty) ? c.teacher : nil'), isTrue);

      // 4. .systemMedium hiển thị teacher khi showTeacher bật
      expect(swiftContent.contains('entry.showTeacher && !c.teacher.isEmpty'), isTrue);
      expect(swiftContent.contains('Text("• \\(c.teacher)")'), isTrue);

      // 5. .systemLarge DayGridCellView hiển thị teacher khi showTeacher bật
      expect(swiftContent.contains('DayGridCellView(day: entry.days[leftIndex], accentColor: Color(hex: entry.accentColorHex) ?? .blue, showTeacher: entry.showTeacher)'), isTrue);
      expect(swiftContent.contains('(showTeacher && !firstClass.teacher.isEmpty) ? firstClass.teacher : nil'), isTrue);
    });

    test('AC-04: Cập Nhật Đồng Bộ Phiên Bản Tại GitHub Actions CI', () {
      final ciFile = File('.github/workflows/dart.yml');
      expect(ciFile.existsSync(), isTrue, reason: '.github/workflows/dart.yml must exist');
      final ciContent = ciFile.readAsStringSync();

      expect(ciContent.contains('tag: v1.1.0'), isTrue,
          reason: 'Release tag in dart.yml must be updated to v1.1.0');
      expect(ciContent.contains('body: "IOS Update 1.1.0 - New update for ios"'), isTrue,
          reason: 'Release body in dart.yml must be updated to IOS Update 1.1.0');
    });
  });
}
