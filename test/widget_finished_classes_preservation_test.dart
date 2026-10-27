import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  LichHoc createMockClass({
    required String tenHocPhan,
    required String thu,
    required String tiet,
    required String phong,
    String tenLopTinChi = 'TH4327_23CN 2',
    String thoiGian = '01/09/2026 - 30/12/2026',
    String giaoVien = 'TS. Nguyễn Văn Hùng',
  }) {
    return LichHoc(
      tenHocPhan: tenHocPhan,
      soTinChi: 3,
      tenLopTinChi: tenLopTinChi,
      thoiGian: thoiGian,
      thu: thu,
      tiet: tiet,
      phong: phong,
      giaoVien: giaoVien,
      hocKy: 1,
      namHoc: '2026-2027',
      dotHoc: 1,
      chuyenNganh: 'CNTT',
    );
  }

  group('SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests', () {
    // Mock dữ liệu: Thứ Hai ngày 26/10/2026, ca chiều từ 12:55 đến 17:05 (Tiết 8-12)
    final mondaySchedule = createMockClass(
      tenHocPhan: 'Kho dữ liệu và khai phá dữ liệu',
      thu: 'Thứ 2',
      tiet: '8-12',
      phong: 'M-M5.03',
    );

    final morningSchedule = createMockClass(
      tenHocPhan: 'Lập trình di động',
      thu: 'Thứ 2',
      tiet: '1-3',
      phong: 'H302',
    );

    test('AC-01: Bảo toàn 100% dữ liệu ca học đã kết thúc trong ngày tại Service lõi', () {
      // Thời điểm kiểm tra: 18:00 ngày 26/10/2026 (sau khi ca học 12:55-17:05 đã kết thúc)
      final currentTime = DateTime(2026, 10, 26, 18, 0);

      final singleDayData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [mondaySchedule],
        layoutMode: 'single_day',
        currentTime: currentTime,
      );

      // Verify AC-01: Ca học không bị drop/continue khỏi classes
      expect(singleDayData.days.isNotEmpty, isTrue);
      final todayClasses = singleDayData.days.first.classes;
      expect(todayClasses.length, equals(1),
          reason: 'Ca học hôm nay đã xong vẫn phải được bảo toàn trong payload, không được rỗng!');

      final classItem = todayClasses.first;
      expect(classItem.courseName, equals('Kho dữ liệu và khai phá dữ liệu'));
      expect(classItem.isFinished, isTrue,
          reason: 'Ca học đã qua 17:05 nên cờ isFinished phải là true');
      expect(classItem.isCurrentOrNext, isFalse,
          reason: 'Ca học đã hoàn thành không được đánh dấu là current/next');
    });

    test('AC-01 Multi-class: Phân định chính xác ca đã xong và ca sắp tới trong ngày', () {
      // Thời điểm kiểm tra: 10:30 ngày 26/10/2026 (sau ca sáng 07:00-09:25, trước ca chiều 12:55-17:05)
      final currentTime = DateTime(2026, 10, 26, 10, 30);

      final singleDayData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [morningSchedule, mondaySchedule],
        layoutMode: 'single_day',
        currentTime: currentTime,
      );

      final classes = singleDayData.days.first.classes;
      expect(classes.length, equals(2), reason: 'Bảo toàn cả 2 ca học trong ngày');

      // Ca sáng: đã hoàn thành
      expect(classes[0].courseName, equals('Lập trình di động'));
      expect(classes[0].isFinished, isTrue);
      expect(classes[0].isCurrentOrNext, isFalse);

      // Ca chiều: sắp tới (current or next)
      expect(classes[1].courseName, equals('Kho dữ liệu và khai phá dữ liệu'));
      expect(classes[1].isFinished, isFalse);
      expect(classes[1].isCurrentOrNext, isTrue);
    });

    test('AC-02: Widget 7 Ngày & 3 Ngày bảo toàn ca học và tính chuẩn Tổng kết tuần', () {
      // Thời điểm: 18:00 ngày Thứ Hai 26/10/2026 (ca duy nhất trong ngày Thứ 2 đã học xong)
      final currentTime = DateTime(2026, 10, 26, 18, 0);

      // 1. Kiểm tra 7 Ngày (Weekly Grid)
      final weeklyData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [mondaySchedule],
        layoutMode: 'seven_days',
        currentTime: currentTime,
      );

      expect(weeklyData.days.length, equals(7));
      final mondayDay = weeklyData.days.firstWhere((d) => d.isToday);
      expect(mondayDay.classes.isNotEmpty, isTrue,
          reason: 'Thứ 2 hôm nay phải có ca học trong classes, không được rỗng dẫn đến "Không có lịch"');
      expect(mondayDay.classes.first.isFinished, isTrue);

      // Verify đếm chuẩn buổi học trong tuần:
      int totalClasses = 0;
      int emptyDays = 0;
      for (final d in weeklyData.days) {
        if (d.classes.isEmpty) {
          emptyDays++;
        } else {
          totalClasses = totalClasses + (d.classes.length as int);
        }
      }
      expect(totalClasses, equals(1), reason: 'Phải tính đủ 1 buổi học trong tuần');
      expect(emptyDays, equals(6),
          reason: 'Chỉ có 6 ngày trống (T3, T4, T5, T6, T7, CN), Thứ 2 đã học xong KHÔNG ĐƯỢC tính là ngày trống!');

      // 2. Kiểm tra 3 Ngày (Three Days)
      final threeDaysData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [mondaySchedule],
        layoutMode: 'three_days',
        currentTime: currentTime,
      );

      expect(threeDaysData.days.length, equals(3));
      final todayInThreeDays = threeDaysData.days.firstWhere((d) => d.isToday);
      expect(todayInThreeDays.classes.isNotEmpty, isTrue);
      expect(todayInThreeDays.classes.first.isFinished, isTrue);
    });

    test('AC-03: Widget 1 Ngày phân biệt rõ "Hôm nay nghỉ" vs "Đã học xong"', () {
      final currentTime = DateTime(2026, 10, 26, 18, 0);

      // Trường hợp 1: Có ca học nhưng đã xong
      final finishedData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [mondaySchedule],
        layoutMode: 'single_day',
        currentTime: currentTime,
      );
      expect(finishedData.days.first.classes.isNotEmpty, isTrue);
      expect(finishedData.days.first.classes.every((c) => c.isFinished), isTrue);

      // Trường hợp 2: Thật sự không có ca học
      final dayOffData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [],
        layoutMode: 'single_day',
        currentTime: currentTime,
      );
      expect(dayOffData.days.first.classes.isEmpty, isTrue,
          reason: 'Không có ca học nào trong TKB thì classes mới là mảng rỗng');
    });

    testWidgets('AC-05: Live Preview trong WidgetStudio hiển thị đúng visual parity khi ca học đã xong', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Màn hình khởi tạo thành công và không bị overflow
      expect(find.byType(WidgetStudioScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-05 Parity: Live Preview giữ nguyên màu môn học và không hiển thị badge [ĐÃ HOÀN THÀNH] / [ĐÃ XONG]', (tester) async {
      final finishedScheduleData = WidgetScheduleData(
        updatedAt: DateTime.now().toIso8601String(),
        widgetTitle: 'Lịch hôm nay',
        widgetSubtitle: 'Thứ Hai, 26/10',
        layoutMode: 'single_day',
        days: [
          WidgetDaySchedule(
            dayLabel: 'HÔM NAY',
            dateStr: '26/10',
            weekdayStr: 'T2',
            isToday: true,
            isDimmed: false,
            classes: [
              const WidgetClassItem(
                courseName: 'Kho dữ liệu và khai phá dữ liệu',
                classCode: 'TH4327_23CN 2',
                timeSlot: '12:55 – 17:05 (T8–12)',
                room: 'P.M-M5.03',
                teacher: 'TS. Nguyễn Văn A',
                isCurrentOrNext: false,
                isFinished: true,
              ),
            ],
          ),
        ],
      );

      final initialPrefs = <String, Object>{
        'widget_schedule_data_single_day': finishedScheduleData.toJsonString(),
        'widget_theme_config': jsonEncode(WidgetThemeConfig.minimalSwiss(layoutMode: 'single_day').toJson()),
      };
      SharedPreferences.setMockInitialValues(initialPrefs);

      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: MaterialApp(
            home: WidgetStudioScreen(
              previewScheduleData: finishedScheduleData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Môn học đã học xong vẫn hiển thị trên Live Preview (không rơi vào 'Không có ca học nào' hay 'Hôm nay nghỉ')
      expect(find.text('Kho dữ liệu và khai phá dữ liệu'), findsWidgets);
      // SPEC-WIDGET-CLEANUP-2X2: Bỏ nhãn [ĐÃ XONG] và [ĐÃ HOÀN THÀNH], giữ nguyên môn học
      expect(find.text('[ĐÃ XONG]'), findsNothing);
      expect(find.text('[ĐÃ HOÀN THÀNH]'), findsNothing);
      expect(find.text('Hôm nay nghỉ'), findsNothing);
    });
  });
}
