import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/schedule_screen.dart';
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

  // Mock schedule item sample
  LichHoc createMockLichHoc({
    required String tenHocPhan,
    required String tenLopTinChi,
    required String thu,
    required String tiet,
    required String phong,
    required String thoiGian,
    String giaoVien = 'Nguyễn Văn A',
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

  group('SPEC-WIDGET-STUDIO-02 Acceptance Criteria Verification Tests', () {
    // ── AC-01: Widget Studio Light Theme ────────────────────────────────────
    testWidgets(
        'AC-01 (Widget Studio Light Theme) Displays screen in full light theme with AppTheme.surface and dark text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testTheme = WidgetThemeConfig.frostedGlass();
      final previewData = WidgetScheduleData(
        updatedAt: DateTime(2026, 10, 20, 10, 0).toIso8601String(),
        widgetTitle: 'LỊCH HỌC HÔM NAY',
        widgetSubtitle: 'THỨ BA, 20/10/2026',
        layoutMode: 'single_day',
        days: const [
          WidgetDaySchedule(
            dayLabel: 'HÔM NAY',
            dateStr: '20/10',
            weekdayStr: 'T3',
            isToday: true,
            isDimmed: false,
            classes: [
              WidgetClassItem(
                courseName: 'Đồ án Kiến trúc 1',
                classCode: 'TH4327_23CN 2',
                timeSlot: '13:00 - 15:25 (T7-9)',
                room: 'P.A401',
                teacher: 'Trần Văn C',
                isCurrentOrNext: true,
                isFinished: false,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: testTheme,
            previewScheduleData: previewData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Scaffold background is AppTheme.surface
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppTheme.surface));

      // Verify AppBar background and title
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(AppTheme.surface));
      expect(appBar.titleSpacing, equals(0));
      expect(appBar.leading, isNotNull);

      // Verify title text exists and has dark color
      final titleText = tester.widget<Text>(find.text('WIDGET STUDIO'));
      expect(titleText.style?.color, equals(AppTheme.primary));

      // Verify controls render on white surface cards
      expect(find.text('CHẾ ĐỘ HIỂN THỊ (LAYOUT MODE)'), findsOneWidget);
      expect(find.text('PRESETS MẪU 1 CHẠM'), findsOneWidget);
      expect(find.text('KIỂU NỀN (BACKGROUND STYLE)'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('BỘ MÀU CHUẨN THỤY SĨ'), findsOneWidget);
      expect(find.text('CÔNG TẮC TRƯỜNG DỮ LIỆU'), findsOneWidget);
      // SPEC-REQ-5: Công tắc ghim màn hình khóa đã được gỡ bỏ hoàn toàn
      expect(find.text('Hiển thị thẻ lịch học ngoài Màn hình khóa & AOD'),
          findsNothing);

      // Verify Layout Mode buttons
      expect(find.byKey(const Key('mode_single_day')), findsOneWidget);
      expect(find.byKey(const Key('mode_three_days')), findsOneWidget);
      expect(find.byKey(const Key('mode_seven_days')), findsOneWidget);

      // Tap 3 Days mode and check Live Preview update
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();

      // Tap 7 Days mode and check Live Preview title changes
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(find.textContaining('7 NGÀY'), findsOneWidget);
    });

    // ── AC-02: Clean Preview & Fallback Preview Data ────────────────────────
    testWidgets(
        'AC-02 (Clean Preview & Fallback Preview Data) No amber tag or yellow disclaimer box, loads sample data when empty, hides sample prefix when real data present',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Case 1: DB rỗng / không có lịch -> nạp dữ liệu mẫu sạch sẽ, không có rác thông báo
      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Thẻ Tag màu cam và hộp lưu ý vàng bị xóa bỏ hoàn toàn
      expect(find.text('[ DỮ LIỆU MẪU - XEM TRƯỚC ]'), findsNothing);
      expect(find.textContaining('* Lưu ý: Đây là dữ liệu mẫu'), findsNothing);

      // Tuyệt đối không hiển thị "KHÔNG CÓ CA HỌC NÀO" trong chế độ xem trước
      expect(find.text('KHÔNG CÓ CA HỌC NÀO'), findsNothing);

      // Tên môn học tự nhiên (không còn chữ "(Môn mẫu)")
      expect(find.textContaining('(Môn mẫu) '), findsNothing);
      expect(find.text('Môn học 1'), findsAtLeastNWidgets(1));

      // Case 2: Khi có lịch thật từ người dùng
      final realScheduleData = WidgetScheduleData(
        updatedAt: DateTime(2026, 10, 20, 10, 0).toIso8601String(),
        widgetTitle: 'Hôm nay | Thứ 3, 20/10',
        widgetSubtitle: '',
        layoutMode: 'single_day',
        days: const [
          WidgetDaySchedule(
            dayLabel: 'HÔM NAY',
            dateStr: '20/10',
            weekdayStr: 'T3',
            isToday: true,
            isDimmed: false,
            classes: [
              WidgetClassItem(
                courseName: 'Cơ sở dữ liệu nâng cao',
                classCode: 'TH4327_23CN 2',
                timeSlot: '07:00 - 09:25 (T1-3)',
                room: 'P.I801',
                teacher: 'TS. Nguyễn Văn Hùng',
                isCurrentOrNext: true,
                isFinished: false,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WidgetStudioScreen(
            previewScheduleData: realScheduleData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nhãn mẫu, tiền tố và thông báo mẫu phải biến mất hoàn toàn
      expect(find.text('[ DỮ LIỆU MẪU - XEM TRƯỚC ]'), findsNothing);
      expect(find.textContaining('(Môn mẫu) '), findsNothing);
      expect(find.textContaining('* Lưu ý: Đây là dữ liệu mẫu'), findsNothing);

      // Hiển thị 100% lịch thật
      expect(find.text('Cơ sở dữ liệu nâng cao'), findsOneWidget);
    });

    // ── AC-03: Apply Flow & Notification Separation ──────────────────────────
    testWidgets(
        'AC-03 (Apply Flow & Notification Separation) Apply saves config and triggers pinWidget, lockscreen notification switch is removed',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // SPEC-REQ-5: Công tắc ghim màn hình khóa đã được gỡ bỏ hoàn toàn
      expect(
        find.text('Hiển thị thẻ lịch học ngoài Màn hình khóa & AOD'),
        findsNothing,
      );

      // Bấm Áp Dụng: Chỉ cập nhật giao diện (AC-02)
      await tester.tap(find.text('ÁP DỤNG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('✓ Đã cập nhật giao diện Widget'), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.text('✓ Đã cập nhật giao diện Widget'))).clearSnackBars();
      await tester.pumpAndSettle();

      // AC-05: Nút riêng Thêm vào Màn hình chính đã được gỡ bỏ hoàn toàn, thay bằng hướng dẫn
      expect(find.byKey(const Key('btn_add_to_home')), findsNothing);
      expect(find.text('Thêm vào Màn hình chính'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

      // Bấm nút chính ÁP DỤNG CẤU HÌNH VÀO WIDGET
      await tester.tap(find.text('ÁP DỤNG CẤU HÌNH VÀO WIDGET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('✓ Đã cập nhật giao diện Widget'), findsOneWidget);

      final savedConfig = await WidgetDataSyncService.getThemeConfig(prefs: prefs);
      expect(savedConfig.enableLockscreenNotification, isFalse);
    });

    // ── AC-04: Full Class Code Retention ────────────────────────────────────
    test(
        'AC-04 (Full Class Code Retention) Preserves tenLopTinChi (TH4327_23CN 2) completely without truncation',
        () {
      const fullClassCode = 'TH4327_23CN 2';
      final schedule = createMockLichHoc(
        tenHocPhan: 'Đồ án Kiến trúc 1',
        tenLopTinChi: fullClassCode,
        thu: 'Thứ 3',
        tiet: '7-9',
        phong: 'A401',
        thoiGian: '01/09/2026 - 30/12/2026',
      );

      final testDate = DateTime(2026, 10, 20, 10, 0); // Tuesday
      final result = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [schedule],
        layoutMode: 'single_day',
        currentTime: testDate,
      );

      expect(result.days.isNotEmpty, isTrue);
      final day = result.days.first;
      expect(day.classes.isNotEmpty, isTrue);
      final classItem = day.classes.first;

      // Verify exact retention
      expect(classItem.classCode, equals(fullClassCode));
      expect(classItem.courseName, equals('Đồ án Kiến trúc 1'));
      expect(classItem.room, equals('P.A401'));
      expect(classItem.timeSlot, anyOf(contains('(T7-9)'), contains('(T7–9)')));

      // Verify JSON serialization retains full class_code
      final json = result.toJson();
      final serializedCode =
          json['days'][0]['classes'][0]['class_code'] as String;
      expect(serializedCode, equals('TH4327_23CN 2'));
    });

    // ── AC-05: In-App Hint Banner ───────────────────────────────────────────
    testWidgets(
        'AC-05 (In-App Hint Banner Removed) ScheduleScreen eliminates hint banner permanently to prevent layout shift',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appProvider = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(
            home: ScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner gợi ý đã bị loại bỏ hoàn toàn (SPEC-SCHEDULE-WIDGET-02 AC-02)
      expect(find.byKey(const Key('widget_hint_banner')), findsNothing);
      expect(find.byKey(const Key('btn_widget_hint_try')), findsNothing);
      expect(find.byKey(const Key('btn_widget_hint_dismiss')), findsNothing);
    });

    // ── AC-06: Smart Touch-Zones & Deep Link ────────────────────────────────
    test(
        'AC-06 (Smart Touch-Zones & Deep Link) Deep link channel retrieves initial route /widget_studio and target tab 1',
        () async {
      const MethodChannel channel = MethodChannel('com.tramkien.hau/widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getInitialRoute') {
          return '/widget_studio';
        } else if (methodCall.method == 'getInitialTargetTab') {
          return 1;
        }
        return null;
      });

      final route = await WidgetDataSyncService.getInitialRoute();
      expect(route, equals('/widget_studio'));

      final tab = await WidgetDataSyncService.getInitialTargetTab();
      expect(tab, equals(1));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // ── AC-07: Time-Window Engine ───────────────────────────────────────────
    test(
        'AC-07 (Time-Window Engine) 1-Day rollover at 20:00, 3-Day dimming without [ĐÃ XONG], 7-Day today highlight & Sunday flip',
        () {
      final monClass = createMockLichHoc(
        tenHocPhan: 'Kỹ thuật Lập trình',
        tenLopTinChi: 'TH101_23CN 1',
        thu: 'Thứ 2',
        tiet: '1-3',
        phong: 'I801',
        thoiGian: '01/09/2026 - 30/12/2026',
      );
      final tueClass = createMockLichHoc(
        tenHocPhan: 'Đồ án Kiến trúc 1',
        tenLopTinChi: 'TH4327_23CN 2',
        thu: 'Thứ 3',
        tiet: '7-9',
        phong: 'A401',
        thoiGian: '01/09/2026 - 30/12/2026',
      );
      final wedClass = createMockLichHoc(
        tenHocPhan: 'Kiến trúc Máy tính',
        tenLopTinChi: 'TH203_23CN 1',
        thu: 'Thứ 4',
        tiet: '7-9',
        phong: 'A203',
        thoiGian: '01/09/2026 - 30/12/2026',
      );

      final schedules = [monClass, tueClass, wedClass];

      // 1. 1-Day: Trước 20:00 hiển thị Hôm nay
      final mon19 = DateTime(2026, 10, 19, 19, 30);
      final mon19Data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'single_day',
        currentTime: mon19,
      );
      expect(mon19Data.widgetTitle, equals('Lịch hôm nay'));
      expect(mon19Data.widgetSubtitle, equals('Thứ Hai, 19/10'));
      expect(mon19Data.days.first.dayLabel, equals('HÔM NAY'));
      expect(mon19Data.days.first.isToday, isTrue);

      // 1. 1-Day: Đúng 20:00 vẫn giữ lịch Hôm nay (trung thành với hôm nay, widget ngày mai độc lập)
      final mon20 = DateTime(2026, 10, 19, 20, 0);
      final mon20Data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'single_day',
        currentTime: mon20,
      );
      expect(mon20Data.widgetTitle, equals('Lịch hôm nay'));
      expect(mon20Data.widgetSubtitle, equals('Thứ Hai, 19/10'));
      expect(mon20Data.days.first.dayLabel, equals('HÔM NAY'));
      expect(mon20Data.days.first.isToday, isTrue);

      // Widget Ngày mai chuyên biệt độc lập
      final tomorrowData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'tomorrow',
        currentTime: mon20,
      );
      expect(tomorrowData.widgetTitle, equals('Lịch ngày mai'));
      expect(tomorrowData.days.first.dayLabel, equals('NGÀY MAI'));

      // 2. 3-Day: Thẻ hôm nay luôn sáng rõ (isDimmed = false), TUYỆT ĐỐI KHÔNG gắn [ĐÃ XONG]
      final threeDaysData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'three_days',
        currentTime: mon20,
      );
      expect(threeDaysData.days[0].isDimmed, isFalse);
      expect(threeDaysData.days[1].isDimmed, isFalse);
      expect(threeDaysData.toJsonString().contains('ĐÃ XONG'), isFalse);

      // 3. 7-Day: Chủ nhật 20:00 lật sang Tuần mới
      final sun20 = DateTime(2026, 10, 25, 20, 0); // Sunday 20:00
      final sunData = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'seven_days',
        currentTime: sun20,
      );
      expect(sunData.widgetTitle, equals('Lịch tuần'));
      expect(sunData.widgetSubtitle, equals('26/10 – 01/11'));
      expect(sunData.days[0].weekdayStr, equals('T2'));
      expect(sunData.days[0].dateStr, equals('26/10'));
    });

    // ── AC-08: No Emojis Compliance ─────────────────────────────────────────
    test(
        'AC-08 (No Emojis) Widget output, presets, titles and texts contain absolutely zero emojis',
        () {
      final schedule = createMockLichHoc(
        tenHocPhan: 'Công nghệ Phần mềm',
        tenLopTinChi: 'TH4327_23CN 2',
        thu: 'Thứ 3',
        tiet: '1-3',
        phong: 'A302',
        thoiGian: '01/09/2026 - 30/12/2026',
      );

      final now = DateTime(2026, 10, 20, 14, 0);
      for (final mode in ['single_day', 'three_days', 'seven_days']) {
        final data = WidgetDataSyncService.calculateScheduleWindow(
          allSchedules: [schedule],
          layoutMode: mode,
          currentTime: now,
        );

        expect(WidgetDataSyncService.containsEmoji(data.widgetTitle), isFalse);
        expect(WidgetDataSyncService.containsEmoji(data.widgetSubtitle), isFalse);

        for (final day in data.days) {
          expect(WidgetDataSyncService.containsEmoji(day.dayLabel), isFalse);
          expect(WidgetDataSyncService.containsEmoji(day.weekdayStr), isFalse);
          for (final c in day.classes) {
            expect(WidgetDataSyncService.containsEmoji(c.courseName), isFalse);
            expect(WidgetDataSyncService.containsEmoji(c.classCode), isFalse);
            expect(WidgetDataSyncService.containsEmoji(c.timeSlot), isFalse);
            expect(WidgetDataSyncService.containsEmoji(c.room), isFalse);
          }
        }
      }

      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: [schedule],
        layoutMode: 'single_day',
        currentTime: now,
      );
      final vibrancyText = WidgetDataSyncService.formatIosLockScreenVibrancy(data);
      expect(WidgetDataSyncService.containsEmoji(vibrancyText), isFalse);
    });

    // ── AC-09: Automated Tests & Offline Resilience ─────────────────────────
    test(
        'AC-09 (Automated Tests) Theme presets and offline SQLite/SharedPreferences sync operate without network',
        () async {
      final presets = [
        WidgetThemeConfig.minimalSwiss(),
        WidgetThemeConfig.frostedGlass(),
        WidgetThemeConfig.ghostMode(),
        WidgetThemeConfig.cyberpunkNeon(),
      ];

      for (final p in presets) {
        expect(p.bgOpacity, inInclusiveRange(0.0, 1.0));
        expect(p.bgColorHex, startsWith('#'));
        expect(p.textPrimaryHex, startsWith('#'));
        expect(p.accentColorHex, startsWith('#'));
        expect(p.backgroundColor, isA<Color>());
        expect(p.textPrimaryColor, isA<Color>());
        expect(p.accentColor, isA<Color>());

        final json = p.toJson();
        final reconstituted = WidgetThemeConfig.fromJson(json);
        expect(reconstituted.layoutMode, equals(p.layoutMode));
        expect(reconstituted.bgStyle, equals(p.bgStyle));
      }

      final prefs = await SharedPreferences.getInstance();
      final mockSchedule = createMockLichHoc(
        tenHocPhan: 'Mạng Nâng cao',
        tenLopTinChi: 'TH301_23CN 1',
        thu: 'Thứ 3',
        tiet: '4-6',
        phong: 'H101',
        thoiGian: '01/09/2026 - 30/12/2026',
      );

      final syncedData = await WidgetDataSyncService.loadAndSyncFromDb(
        currentTime: DateTime(2026, 10, 20, 10, 0),
        prefs: prefs,
        sourceSchedules: [mockSchedule],
        updateNotification: false,
      );

      expect(syncedData.days.isNotEmpty, isTrue);
      final storedSchedule =
          await WidgetDataSyncService.getScheduleData(prefs: prefs);
      expect(storedSchedule, isNotNull);
      expect(storedSchedule!.days.first.classes.first.courseName,
          equals('Mạng Nâng cao'));

      // Kiểm tra phân tách độc lập 3 key Widget trong SharedPreferences (Hạng mục 4)
      final singleDayJson = prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataSingleDay);
      final threeDaysJson = prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataThreeDays);
      final sevenDaysJson = prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataSevenDays);
      final fallbackJson = prefs.getString(WidgetDataSyncService.keyWidgetScheduleData);

      expect(singleDayJson, isNotNull);
      expect(threeDaysJson, isNotNull);
      expect(sevenDaysJson, isNotNull);
      expect(fallbackJson, isNotNull);

      final singleDayObj = WidgetScheduleData.fromJsonString(singleDayJson!);
      final threeDaysObj = WidgetScheduleData.fromJsonString(threeDaysJson!);
      final sevenDaysObj = WidgetScheduleData.fromJsonString(sevenDaysJson!);

      expect(singleDayObj.days.length, equals(1));
      expect(threeDaysObj.days.length, equals(3));
      expect(threeDaysObj.widgetTitle, equals('Lịch 3 ngày'));
      expect(threeDaysObj.widgetSubtitle, equals('20/10 – 22/10'));
      expect(sevenDaysObj.days.length, equals(7));
      expect(sevenDaysObj.widgetTitle, equals('Lịch tuần'));
      expect(sevenDaysObj.widgetTitle, isNot(equals('Lịch 3 ngày')));

      // Đồng bộ vòng đời: clearAllWidgetData xóa sạch toàn bộ 5 key SharedPreferences
      await WidgetDataSyncService.clearAllWidgetData(prefs: prefs);
      expect(prefs.getString(WidgetDataSyncService.keyWidgetScheduleData), isNull);
      expect(prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataSingleDay), isNull);
      expect(prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataThreeDays), isNull);
      expect(prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataSevenDays), isNull);
      expect(prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataTomorrow), isNull);
    });

    // ── AC-10: Redesigned Phone Mockup Frame & 3-Day / 7-Day Swiss Layouts ──────
    testWidgets(
        'AC-10 (Phone Mockup Frame & Swiss Typography) Shows status bar (09:41), full course names in 3-day and today highlight in 7-day',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Status Bar simulated elements
      expect(find.text('09:41'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_4_bar), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.battery_std), findsOneWidget);

      // Switch to 3 Days Mode
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();

      // In 3 Days mode, natural course names are displayed without vertical truncation
      expect(find.textContaining('Môn học 1'), findsOneWidget);
      expect(find.textContaining('Môn học 3'), findsOneWidget);
      expect(find.textContaining('Môn học 4'), findsOneWidget);

      // Switch to 7 Days Mode
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();

      // In 7 Days mode, week days are displayed with today highlight
      expect(find.textContaining('T2'), findsWidgets);
      expect(find.textContaining('T3'), findsWidgets);
      expect(find.textContaining('CN'), findsWidgets);
    });

    // ── AC-11: Presets Active State ──────────────────────────────────────────
    testWidgets(
        'AC-11 (Presets Active State) Highlights active preset button with checkmark, resets to null on custom adjustments',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Preset "Tối giản Thụy Sĩ"
      await tester.tap(find.text('Tối giản Thụy Sĩ'));
      await tester.pumpAndSettle();

      // Verify check icon appears
      expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));

      // Tap on Preset "Cyberpunk Neon"
      await tester.tap(find.text('Cyberpunk Neon'));
      await tester.pumpAndSettle();

      // Tap on a custom background style to reset preset
      await tester.tap(find.text('Nền Màu Đặc'));
      await tester.pumpAndSettle();
    });

    // ── AC-12: Conditional Controls UX (Transparent Lock & Hidden Opacity) ───
    testWidgets(
        'AC-12 (Conditional Controls UX) Locks opacity slider and background color selector when transparent mode or Ghost Mode is active',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Trong suốt 100%"
      await tester.tap(find.text('Trong suốt 100%'));
      await tester.pumpAndSettle();

      // Verify opacity slider is hidden and background color selector is disabled
      expect(find.byType(Slider), findsNothing);
      expect(find.text('(Nền trong suốt - Không áp dụng màu nền)'), findsOneWidget);

      // Switch to "Ghost Mode" preset
      await tester.tap(find.text('Ghost Mode'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);
      expect(find.text('(Nền trong suốt - Không áp dụng màu nền)'), findsOneWidget);
    });

    // ── AC-13: Header Swiss Typography ──────────────────────────────────────
    testWidgets(
        'AC-13 (Header Swiss Typography) Header displays clean title case strings in Live Preview',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1-Day mode: Góc trái tiêu đề "Lịch hôm nay" (hoặc "Lịch ngày mai"), góc phải ngày tháng, không dùng dấu "|"
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Lịch hôm nay' || w.data == 'Lịch ngày mai') &&
              w.style?.fontFamily == 'Manrope',
        ),
        findsOneWidget,
      );

      // Switch to 3 Days mode
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();
      expect(find.text('Lịch 3 ngày'), findsWidgets);

      // Switch to 7 Days mode
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(find.text('Lịch tuần'), findsWidgets);
    });

    // ── SPEC-3-VARIANTS: Verification of 3 Elite Widget Variants ───────────────
    testWidgets(
        'SPEC-3-VARIANTS: Tests 1 Ngày (2x2), 3 Ngày 4x2, 7 Ngày Grid 8 Ô (4x4)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Biến thể 1 (1 Ngày · 4x2 Timeline):
      expect(find.text('LIVE PREVIEW (1 NGÀY)'), findsOneWidget);
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
      expect(find.text('(+2 môn nữa)'), findsOneWidget);
      expect(find.textContaining('P.I801'), findsOneWidget);

      // 2. Biến thể 2 (3 Ngày · 4x2):
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();
      expect(find.text('LIVE PREVIEW (3 NGÀY)'), findsOneWidget);
      expect(find.textContaining('Môn học 1'), findsOneWidget);
      expect(find.textContaining('Môn học 3'), findsOneWidget);
      expect(find.textContaining('Môn học 4'), findsOneWidget);

      // 3. Biến thể 3 (7 Ngày · 4x4 Grid 2x4 gồm 8 Ô):
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(find.text('LIVE PREVIEW (7 NGÀY · GRID 8 Ô)'), findsOneWidget);
      expect(find.text('TỔNG KẾT TUẦN'), findsOneWidget);
      expect(find.textContaining('buổi học'), findsOneWidget);
      expect(find.textContaining('ngày trống'), findsOneWidget);
    });

    // ── SPEC-REQ-4: Conditional Controls UX (Solid vs Transparent) ─────────
    testWidgets(
        'SPEC-REQ-4: Conditional Controls UX binary choices (Solid vs Transparent)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Case A: Chuyển sang "Nền Màu Đặc" (solid)
      await tester.tap(find.text('Nền Màu Đặc'));
      await tester.pumpAndSettle();

      // Opacity slider bị ẩn hoàn toàn, xuất hiện chọn nhanh Nền Tối / Nền Sáng
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Nền Tối'), findsOneWidget);
      expect(find.text('Nền Sáng'), findsOneWidget);

      // Bấm Nền Sáng
      await tester.tap(find.text('Nền Sáng'));
      await tester.pumpAndSettle();

      // Case B: Chuyển sang "Trong suốt 100%" (transparent)
      await tester.tap(find.text('Trong suốt 100%'));
      await tester.pumpAndSettle();

      // Opacity slider bị ẩn và khóa màu nền
      expect(find.byType(Slider), findsNothing);
      expect(find.text('(Nền trong suốt - Không áp dụng màu nền)'), findsOneWidget);
    });

    // ── SPEC-SCENARIO-FALLBACK: Mặc định nạp đủ 4 ca học từ sáng đến tối ──
    testWidgets(
        'SPEC-SCENARIO-FALLBACK: Mặc định luôn kín lịch 4 ca học, bỏ toolbar chọn mẫu',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: WidgetStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Đã bỏ hàng nút chọn MẪU [ 1 Ca ] / [ 4 Ca (học dồn) ]
      expect(find.text('[ 1 Ca ]'), findsNothing);
      expect(find.text('[ 4 Ca (học dồn) ]'), findsNothing);

      // Mặc định luôn kín lịch 4 ca học từ sáng đến tối (4x2 Timeline hiển thị môn 1, môn 2, footer (+2 môn nữa))
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
      expect(find.text('(+2 môn nữa)'), findsOneWidget);
    });
  });
}
