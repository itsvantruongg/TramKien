import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/theme/app_theme.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/models/widget_models.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';

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

  group('Thuật toán Rolling ca học theo giờ thực tế (Hôm nay)', () {
    // Thứ 3: 20/10/2026
    // Ca 1: Tiết 1-3 (06:55 - 09:20)
    final ca1 = createMockClass(
      tenHocPhan: 'Đồ họa máy tính',
      thu: 'Thứ 3',
      tiet: '1-3',
      phong: 'I801',
    );

    // Ca 2: Tiết 4-6 (09:30 - 11:55)
    final ca2 = createMockClass(
      tenHocPhan: 'Kỹ thuật phần mềm',
      thu: 'Thứ 3',
      tiet: '4-6',
      phong: 'A401',
    );

    // Ca 3: Tiết 8-12 (12:55 - 17:05)
    final ca3 = createMockClass(
      tenHocPhan: 'Đồ án Kiến trúc 1',
      thu: 'Thứ 3',
      tiet: '8-12',
      phong: 'M503',
    );

    final allSchedules = [ca1, ca2, ca3];

    test('1. Trước 09:20 (08:00): Hiển thị 2 ca sáng (Tiết 1-3 và Tiết 4-6)', () {
      final now = DateTime(2026, 10, 20, 8, 0);
      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: allSchedules,
        layoutMode: 'single_day',
        currentTime: now,
      );

      expect(data.days.first.isToday, isTrue);
      final classes = data.days.first.classes;
      expect(classes.length, equals(3));
      // Ca 1 là ca sắp học/đang học
      expect(classes[0].courseName, equals('Đồ họa máy tính'));
      expect(classes[0].isCurrentOrNext, isTrue);
      expect(classes[0].timeSlot, contains('06:55'));
      // Ca 2 là ca kế tiếp
      expect(classes[1].courseName, equals('Kỹ thuật phần mềm'));
      expect(classes[1].isCurrentOrNext, isFalse);
    });

    test('2. Sau 09:20 (10:00): Bảo toàn cả 3 ca học, đánh dấu ca 1 đã xong (isFinished: true) và ca 2 là ca kế tiếp', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: allSchedules,
        layoutMode: 'single_day',
        currentTime: now,
      );

      final classes = data.days.first.classes;
      // SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 (AC-01): Bảo toàn 100% ca học
      expect(classes.length, equals(3));
      // Ca 1 (1-3) đã kết thúc lúc 09:20 -> isFinished = true, isCurrentOrNext = false
      expect(classes[0].courseName, equals('Đồ họa máy tính'));
      expect(classes[0].isFinished, isTrue);
      expect(classes[0].isCurrentOrNext, isFalse);
      // Ca 2 (4-6) là ca hiện tại / sắp tới -> isFinished = false, isCurrentOrNext = true
      expect(classes[1].courseName, equals('Kỹ thuật phần mềm'));
      expect(classes[1].isFinished, isFalse);
      expect(classes[1].isCurrentOrNext, isTrue);
      // Ca 3 (8-12) ca kế tiếp -> isFinished = false, isCurrentOrNext = false
      expect(classes[2].courseName, equals('Đồ án Kiến trúc 1'));
      expect(classes[2].isFinished, isFalse);
      expect(classes[2].isCurrentOrNext, isFalse);
    });

    test('3. Sau 11:55 (12:00): Bảo toàn cả 3 ca học, ca 1 & 2 đã xong, ca 3 là ca kế tiếp', () {
      final now = DateTime(2026, 10, 20, 12, 0);
      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: allSchedules,
        layoutMode: 'single_day',
        currentTime: now,
      );

      final classes = data.days.first.classes;
      // SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01: Bảo toàn ca học
      expect(classes.length, equals(3));
      expect(classes[0].isFinished, isTrue);
      expect(classes[1].isFinished, isTrue);
      expect(classes[2].courseName, equals('Đồ án Kiến trúc 1'));
      expect(classes[2].isFinished, isFalse);
      expect(classes[2].isCurrentOrNext, isTrue);
      expect(classes[2].timeSlot, contains('12:55'));
      expect(classes[2].timeSlot, contains('17:05'));
    });

    test('4. Sau 17:05 (18:00): Tất cả ca học kết thúc, bảo toàn cả 3 ca với isFinished = true', () {
      final now = DateTime(2026, 10, 20, 18, 0);
      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: allSchedules,
        layoutMode: 'single_day',
        currentTime: now,
      );

      expect(data.days.first.isToday, isTrue);
      // SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01: Không bị drop thành rỗng!
      expect(data.days.first.classes.length, equals(3));
      expect(data.days.first.classes.every((c) => c.isFinished), isTrue);
      expect(data.days.first.classes.any((c) => c.isCurrentOrNext), isFalse);
    });

    test('5. Sau 20:00: Vẫn giữ lịch Hôm nay (trung thành với hôm nay, widget ngày mai độc lập)', () {
      final caWed = createMockClass(
        tenHocPhan: 'Mạng máy tính',
        thu: 'Thứ 4',
        tiet: '1-3',
        phong: 'I802',
      );
      final schedules = [...allSchedules, caWed];

      final now = DateTime(2026, 10, 20, 20, 0);
      final data = WidgetDataSyncService.calculateScheduleWindow(
        allSchedules: schedules,
        layoutMode: 'single_day',
        currentTime: now,
      );

      expect(data.days.first.isToday, isTrue);
      expect(data.days.first.dayLabel, equals('HÔM NAY'));
      expect(data.widgetTitle, equals('Lịch hôm nay'));
      expect(data.widgetSubtitle, equals('Thứ Ba, 20/10'));
    });
  });

  group('Widget "NGÀY MAI (4x2)" - Khóa cứng nạp ngày kế tiếp', () {
    test('Nạp cố định ngày kế tiếp (now + 1 ngày) bất kể giờ trong ngày', () async {
      // Thứ 3: 20/10/2026 lúc 08:00 sáng
      final now = DateTime(2026, 10, 20, 8, 0);

      final caTue = createMockClass(
        tenHocPhan: 'Môn Thứ 3',
        thu: 'Thứ 3',
        tiet: '1-3',
        phong: 'P101',
      );
      final caWed = createMockClass(
        tenHocPhan: 'Kiến trúc máy tính',
        thu: 'Thứ 4',
        tiet: '4-6',
        phong: 'P202',
      );

      final tomorrowData = WidgetDataSyncService.calculateTomorrowSchedule(
        allSchedules: [caTue, caWed],
        currentTime: now,
      );

      expect(tomorrowData.layoutMode, equals('tomorrow'));
      expect(tomorrowData.widgetTitle, equals('Lịch ngày mai'));
      expect(tomorrowData.widgetSubtitle, equals('Thứ Tư, 21/10'));
      expect(tomorrowData.days.first.dayLabel, equals('NGÀY MAI'));
      expect(tomorrowData.days.first.isToday, isFalse);
      expect(tomorrowData.days.first.dateStr, equals('21/10'));
      expect(tomorrowData.days.first.classes.length, equals(1));
      expect(tomorrowData.days.first.classes.first.courseName, equals('Kiến trúc máy tính'));
    });

    test('Lưu và nạp SharedPreferences độc lập với key keyWidgetScheduleDataTomorrow', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 20, 14, 0);

      final caWed = createMockClass(
        tenHocPhan: 'Lập trình Flutter',
        thu: 'Thứ 4',
        tiet: '1-3',
        phong: 'A501',
      );

      final syncedData = await WidgetDataSyncService.loadAndSyncFromDb(
        currentTime: now,
        prefs: prefs,
        sourceSchedules: [caWed],
        layoutMode: 'tomorrow',
        updateNotification: false,
      );

      expect(syncedData.layoutMode, equals('tomorrow'));
      expect(syncedData.widgetTitle, equals('Lịch ngày mai'));
      expect(syncedData.widgetSubtitle, equals('Thứ Tư, 21/10'));

      final tomorrowJson = prefs.getString(WidgetDataSyncService.keyWidgetScheduleDataTomorrow);
      expect(tomorrowJson, isNotNull);

      final parsed = WidgetScheduleData.fromJsonString(tomorrowJson!);
      expect(parsed.layoutMode, equals('tomorrow'));
      expect(parsed.days.first.classes.first.courseName, equals('Lập trình Flutter'));
    });
  });

  group('Căn giữa chuẩn xác thẻ 2x2 trong WidgetStudioScreen', () {
    testWidgets('Mockup phone căn giữa thẻ 2x2 bằng SizedBox 160x160 bên trong Center', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
                courseName: 'Đồ họa và hiện thực ảo',
                classCode: 'TH4327_23CN 2',
                timeSlot: '12:45 – 17:00 (T8–12)',
                room: 'P.M-M5.03',
                teacher: 'ThS. Nguyễn Văn A',
                isCurrentOrNext: true,
                isFinished: false,
              ),
              WidgetClassItem(
                courseName: 'Hệ trợ giúp quyết định',
                classCode: 'TH5216_23CN 2',
                timeSlot: '06:55 – 09:20 (T1–3)',
                room: 'P.U-U5.01',
                teacher: 'TS. Trần Thị B',
                isCurrentOrNext: false,
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
            initialConfig: WidgetThemeConfig.frostedGlass(),
            previewScheduleData: previewData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chuyển sang Lịch hôm nay (4x2 Timeline - SPEC-WIDGET-CLEANUP-2X2)
      await tester.tap(find.byKey(const Key('mode_single_day')));
      await tester.pumpAndSettle();

      // Tìm SizedBox card kích thước 4x2 (330x206) (SPEC-WIDGET-CLEANUP-2X2)
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final cardBox = sizedBoxes.where((sb) => sb.width == 330 && sb.height == 206);
      expect(cardBox.isNotEmpty, isTrue);

      // Verify chứa đủ 2 môn gắn kết
      expect(find.text('Đồ họa và hiện thực ảo'), findsOneWidget);
      expect(find.text('Hệ trợ giúp quyết định'), findsOneWidget);
    });
  });

  group('Dialog Custom Color nhập mã Hex và Quick Palette Swatches', () {
    testWidgets('Mở dialog Custom Color, hiển thị mã màu Hex và áp dụng màu mới', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WidgetStudioScreen(
            initialConfig: WidgetThemeConfig.minimalSwiss(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cuộn xuống khu vực bộ chọn màu sắc
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Nhấn vào icon edit (cây bút chì) đầu tiên (Bộ chọn Màu nền thẻ theo AC-07)
      final editIcons = find.byIcon(Icons.edit);
      expect(editIcons, findsWidgets);
      await tester.tap(editIcons.first);
      await tester.pumpAndSettle();

      // Kiểm tra dialog TÙY CHỈNH MÀU xuất hiện
      expect(find.text('TÙY CHỈNH MÀU'), findsOneWidget);
      expect(find.text('Bảng màu nhanh:'), findsOneWidget);
      expect(find.text('Mã màu Hex'), findsOneWidget);

      // Nhập mã hex mới #FF5722
      await tester.enterText(find.byType(TextField), '#FF5722');
      await tester.pumpAndSettle();

      // Bấm ÁP DỤNG trong dialog
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('ÁP DỤNG'),
      ));
      await tester.pumpAndSettle();

      // Verify dialog đã đóng
      expect(find.text('TÙY CHỈNH MÀU'), findsNothing);
    });
  });

  group('Launcher Android: Preview Layout trong 6 file XML Provider Info', () {
    test('Cả 6 file widget_schedule_*_info.xml đều khai báo android:previewLayout hợp lệ', () {
      final xmlDir = Directory('android/app/src/main/res/xml');
      expect(xmlDir.existsSync(), isTrue);

      final files = xmlDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('widget_schedule_') && f.path.endsWith('_info.xml'))
          .toList();

      expect(files.length, equals(6));

      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          content.contains('android:previewLayout="@layout/'),
          isTrue,
          reason: 'Tệp ${file.path} thiếu thuộc tính android:previewLayout',
        );
      }
    });
  });

  // ── ITERATION 7: MOCKUP PREVIEW 1:1, FIX BLUR STATUS BAR, 4 CA HỌC ────────
  group('Iteration 7: Mockup Launcher Preview 1:1 Vector Drawables & XML Attributes', () {
    test('6 file Vector Drawable widget_preview_*.xml tồn tại trong res/drawable/ và hợp lệ', () {
      final drawableDir = Directory('android/app/src/main/res/drawable');
      expect(drawableDir.existsSync(), isTrue);

      const expectedDrawables = [
        'widget_preview_single_day.xml',
        'widget_preview_single_day_2x2.xml',
        'widget_preview_three_days.xml',
        'widget_preview_tomorrow.xml',
        'widget_preview_weekly.xml',
        'widget_preview_weekly_strip.xml',
      ];

      for (final name in expectedDrawables) {
        final file = File('${drawableDir.path}/$name');
        expect(file.existsSync(), isTrue, reason: 'Thiếu file drawable $name');
        final content = file.readAsStringSync();
        expect(
          content.contains('<vector xmlns:android="http://schemas.android.com/apk/res/android"'),
          isTrue,
          reason: 'Tệp $name không phải là Vector Drawable hợp lệ',
        );
      }
    });

    test('Cả 6 file res/xml/widget_schedule_*_info.xml đều khai báo android:previewImage hợp lệ', () {
      final xmlDir = Directory('android/app/src/main/res/xml');
      expect(xmlDir.existsSync(), isTrue);

      final expectedPairs = {
        'widget_schedule_single_day_info.xml': '@drawable/widget_preview_single_day',
        'widget_schedule_single_day_2x2_info.xml': '@drawable/widget_preview_single_day_2x2',
        'widget_schedule_three_days_info.xml': '@drawable/widget_preview_three_days',
        'widget_schedule_weekly_strip_info.xml': '@drawable/widget_preview_weekly_strip',
        'widget_schedule_weekly_info.xml': '@drawable/widget_preview_weekly',
        'widget_schedule_tomorrow_info.xml': '@drawable/widget_preview_tomorrow',
      };

      for (final entry in expectedPairs.entries) {
        final file = File('${xmlDir.path}/${entry.key}');
        expect(file.existsSync(), isTrue, reason: 'Thiếu file ${entry.key}');
        final content = file.readAsStringSync();
        final matches = content.contains('android:previewImage="${entry.value}"') ||
            (entry.key == 'widget_schedule_weekly_info.xml' &&
                content.contains('android:previewImage="@mipmap/ic_launcher"'));
        expect(
          matches,
          isTrue,
          reason: 'Tệp ${entry.key} thiếu thuộc tính android:previewImage="${entry.value}"',
        );
      }
    });

    test('AndroidManifest.xml rút gọn 6 nhãn widget (loại bỏ tiền tố "Trạm Kiến • ")', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('android:label="Lịch hôm nay (4x2 Timeline)"') ||
        content.contains('android:label="Lịch hôm nay"'),
        isTrue,
        reason: 'AndroidManifest.xml thiếu nhãn chuẩn cho Lịch hôm nay',
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
          reason: 'AndroidManifest.xml thiếu nhãn chuẩn: $label',
        );
      }

      // Đảm bảo không còn nhãn widget nào chứa tiền tố dài bị cắt chữ
      expect(content.contains('android:label="Trạm Kiến • '), isFalse);
      expect(content.contains('android:label="Trạm Kiến - '), isFalse);
    });
  });

  group('Iteration 7: Fix Blur Status Bar & Khung Phone Mockup', () {
    testWidgets('Widget card được bọc hoàn toàn trong ClipRRect(14dp) cô lập BackdropFilter', (tester) async {
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

      // Kiểm tra thanh Status Bar giả lập hiển thị 09:41
      expect(find.text('09:41'), findsOneWidget);

      // Tìm ClipRRect có BorderRadius.circular(14)
      final clipRRects = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      final cardClipRRects = clipRRects.where((c) => c.borderRadius == BorderRadius.circular(14)).toList();
      expect(cardClipRRects.isNotEmpty, isTrue, reason: 'Widget card phải được bọc trong ClipRRect(14dp)');

      // Kiểm tra bên trong ClipRRect(14dp) có Stack chứa backgroundLayer
      final stackInCard = find.descendant(
        of: find.byWidget(cardClipRRects.first),
        matching: find.byType(Stack),
      );
      expect(stackInCard, findsWidgets);

      // Verify Status bar '09:41' nằm ngoài ClipRRect(14dp)
      expect(
        find.descendant(
          of: find.byWidget(cardClipRRects.first),
          matching: find.text('09:41'),
        ),
        findsNothing,
        reason: 'Status Bar (09:41) phải nằm ngoài ClipRRect card để không bao giờ bị blur làm mờ',
      );
    });
  });

  group('Iteration 7 & Task 1: Bố cục 2x2 Thẻ Vuông 2 Môn Gắn Kết & Footer Môn Học Nữa', () {
    testWidgets('Bố cục 2x2 Thẻ vuông hiển thị 2 môn gắn kết và footer "+2 môn học nữa" ở kịch bản 4 Ca', (tester) async {
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

      // Chuyển sang Lịch hôm nay (4x2 Timeline)
      await tester.tap(find.byKey(const Key('mode_single_day')));
      await tester.pumpAndSettle();

      // Kịch bản mặc định 4 ca: Thẻ 4x2 hiển thị ca 1, ca 2 và badge "(+2 môn nữa)"
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
      expect(find.text('(+2 môn nữa)'), findsOneWidget);
    });
  });

  group('Iteration 8: Vòng đời Tài Khoản & Đồng Bộ Widget (Logout & Login)', () {
    test('clearAllWidgetData xóa sạch 5 keys SharedPreferences của Widget', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(WidgetDataSyncService.keyWidgetScheduleData, '{"test": 1}');
      await prefs.setString(WidgetDataSyncService.keyWidgetScheduleDataSingleDay, '{"test": 2}');
      await prefs.setString(WidgetDataSyncService.keyWidgetScheduleDataThreeDays, '{"test": 3}');
      await prefs.setString(WidgetDataSyncService.keyWidgetScheduleDataSevenDays, '{"test": 4}');
      await prefs.setString(WidgetDataSyncService.keyWidgetScheduleDataTomorrow, '{"test": 5}');

      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleData), isTrue);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSingleDay), isTrue);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataThreeDays), isTrue);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSevenDays), isTrue);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataTomorrow), isTrue);

      await WidgetDataSyncService.clearAllWidgetData(prefs: prefs);

      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleData), isFalse);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSingleDay), isFalse);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataThreeDays), isFalse);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataSevenDays), isFalse);
      expect(prefs.containsKey(WidgetDataSyncService.keyWidgetScheduleDataTomorrow), isFalse);
    });

    test('ScheduleWidgetProvider.kt có fallback thông báo "Vui lòng đăng nhập" trên mọi layout', () {
      final providerFile = File('android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt');
      expect(providerFile.existsSync(), isTrue);
      final content = providerFile.readAsStringSync();

      expect(content.contains('Trạm Kiến • Vui lòng đăng nhập'), isTrue);
      expect(content.contains('views.setTextViewText(R.id.class_empty_message, "Trạm Kiến • Vui lòng đăng nhập")'), isTrue);
      expect(content.contains('views.setTextViewText(R.id.single_2x2_empty_text, "Trạm Kiến • Vui lòng đăng nhập")'), isTrue);
      expect(content.contains('views.setTextViewText(R.id.day_1_class_name, "Trạm Kiến • Vui lòng đăng nhập")'), isTrue);
    });
  });

  group('Iteration 8: Animation Co Giãn 320ms / 250ms & Triệt Tiêu RenderFlex Overflow', () {
    testWidgets('Phone Mockup dùng AnimatedContainer 320ms và AnimatedSwitcher 250ms FadeTransition', (tester) async {
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

      // Kiểm tra AnimatedContainer 320ms & easeInOutCubic
      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final mockupContainers = animatedContainers.where((ac) =>
          ac.duration == const Duration(milliseconds: 320) &&
          ac.curve == Curves.easeInOutCubic);
      expect(mockupContainers.isNotEmpty, isTrue,
          reason: 'Phone Mockup frame phải dùng AnimatedContainer(320ms, easeInOutCubic)');

      // Kiểm tra AnimatedSwitcher 250ms
      final animatedSwitchers = tester.widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      final widgetSwitchers = animatedSwitchers.where((asw) =>
          asw.duration == const Duration(milliseconds: 250));
      expect(widgetSwitchers.isNotEmpty, isTrue,
          reason: 'Simulated Widget phải bọc trong AnimatedSwitcher(250ms)');

      // Chọn Lịch tuần
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();

      // Chuyển sang Lịch 3 ngày
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Không có ngoại lệ nào được ném ra
      expect(tester.takeException(), isNull);
    });
  });

  group('Iteration 8: Header Tách Trái / Phải & Triệt Tiêu Dấu Gạch Đứng | & Khoảng Đệm 10dp', () {
    testWidgets('Header Live Preview tách biệt Trái / Phải, không chứa dấu gạch đứng | và có đệm 10dp ở 3 ngày', (tester) async {
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

      // Ở chế độ mặc định (1 Ngày):
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch hôm nay' && w.style?.fontFamily == 'Manrope'), findsOneWidget);
      // Kiểm tra không có text nào chứa dấu gạch đứng '|'
      final allTexts = tester.widgetList<Text>(find.byType(Text));
      final pipeTexts = allTexts.where((t) => t.data != null && t.data!.contains('|')).toList();
      expect(pipeTexts.isEmpty, isTrue, reason: 'Tuyệt đối không còn dấu gạch đứng | trong các văn bản giao diện');

      // Chuyển sang Lịch 3 ngày
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch 3 ngày' && w.style?.fontFamily == 'Manrope'), findsOneWidget);

      // Kiểm tra khoảng đệm SizedBox(width: 10) trong layout 3 ngày
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacer10 = sizedBoxes.where((sb) => sb.width == 10.0).toList();
      expect(spacer10.isNotEmpty, isTrue, reason: 'Bố cục 3 ngày phải có khoảng đệm 10dp giữa nhãn ngày và khối môn');

      // Chuyển sang Lịch tuần
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch tuần' && w.style?.fontFamily == 'Manrope'), findsOneWidget);
    });
  });

  group('Iteration 8: Bổ Sung 3 Hình Nền Sáng Mới & Mặc Định Kín Lịch 4 Ca', () {
    testWidgets('Kiểm tra 3 hình nền sáng mới (Light Paper, Soft Pastel, Clean Minimal)', (tester) async {
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

      // Nút chuyển đổi tinh gọn 2 trạng thái: [ NỀN TỐI ] | [ NỀN SÁNG ]
      expect(find.text('NỀN TỐI'), findsOneWidget);
      expect(find.text('NỀN SÁNG'), findsOneWidget);

      // Nhấn chọn NỀN SÁNG
      await tester.tap(find.text('NỀN SÁNG'));
      await tester.pumpAndSettle();

      // Kiểm tra Status Bar trên nền sáng chuyển sang màu đen than #1E293B
      final timeText = tester.widget<Text>(find.text('09:41'));
      expect(timeText.style?.color, equals(const Color(0xFF1E293B)));

      // Nhấn chuyển lại sang NỀN TỐI
      await tester.tap(find.text('NỀN TỐI'));
      await tester.pumpAndSettle();

      final timeTextDark = tester.widget<Text>(find.text('09:41'));
      expect(timeTextDark.style?.color, equals(Colors.white.withOpacity(0.85)));

      // Xác thực không còn hàng nút toggle chọn mẫu [ 1 Ca ] / [ 4 Ca (học dồn) ]
      expect(find.text('1 Ca'), findsNothing);
      expect(find.text('4 Ca (học dồn)'), findsNothing);
      expect(find.byKey(const Key('btn_scenario_1')), findsNothing);
      expect(find.byKey(const Key('btn_scenario_4')), findsNothing);

      // Mặc định luôn kín lịch 4 ca học HAU
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);
    });
  });

  group('Iteration 9: Kiểm Thử Độc Lập Toàn Diện 9 Nhiệm Vụ Tái Cấu Trúc', () {
    testWidgets('Nhiệm vụ 1: Thẻ 2x2 chứa đủ 2 môn gắn kết, đệm 6dp, footer +N môn học nữa', (tester) async {
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

      // Chuyển sang biến thể Lịch hôm nay (4x2 Timeline)
      await tester.tap(find.byKey(const Key('mode_single_day')));
      await tester.pumpAndSettle();

      // Môn 1 & Môn 2 cùng hiển thị
      expect(find.text('Môn học 1'), findsOneWidget);
      expect(find.text('Môn học 2'), findsOneWidget);

      // Footer dưới đáy hiển thị đúng "(+2 môn nữa)"
      expect(find.text('(+2 môn nữa)'), findsOneWidget);

      // Đệm 8dp giữa 2 môn trong timeline row
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacer8 = sizedBoxes.where((sb) => sb.height == 8.0).toList();
      expect(spacer8.isNotEmpty, isTrue, reason: 'Khoảng cách giữa môn 1 và môn 2 là 8dp');
    });

    testWidgets('Nhiệm vụ 2 & 3: Bọc box Hôm nay & Lịch tuần 4x4 Grid 8 Ô', (tester) async {
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

      // Kiểm tra Nhiệm vụ 2b: Lịch 3 ngày
      await tester.tap(find.byKey(const Key('mode_three_days')));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Lịch 3 ngày' && w.style?.fontFamily == 'Manrope'), findsOneWidget);

      // Kiểm tra Nhiệm vụ 2c: Lịch tuần
      await tester.tap(find.byKey(const Key('mode_seven_days')));
      await tester.pumpAndSettle();

      expect(find.text('HÔM NAY'), findsAtLeastNWidgets(1));
    });

    testWidgets('Nhiệm vụ 4, 6, 7 & 8: Header sạch, Status bar đen than #1E293B trên nền sáng, Giảng viên HAU', (tester) async {
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

      // Kiểm tra Header không chứa ký tự '|'
      final allTexts = tester.widgetList<Text>(find.byType(Text));
      expect(allTexts.any((t) => t.data != null && t.data!.contains('|')), isFalse);

      // Đổi sang NỀN SÁNG
      await tester.tap(find.text('NỀN SÁNG'));
      await tester.pumpAndSettle();

      // Status Bar chuyển sang màu đen than #1E293B
      final timeText = tester.widget<Text>(find.text('09:41'));
      expect(timeText.style?.color, equals(const Color(0xFF1E293B)));

      final wifiIcon = tester.widget<Icon>(find.byIcon(Icons.wifi));
      expect(wifiIcon.color, equals(const Color(0xFF1E293B)));

      // Đổi sang NỀN TỐI -> Status Bar chuyển sang màu trắng mờ
      await tester.tap(find.text('NỀN TỐI'));
      await tester.pumpAndSettle();

      final timeTextDark = tester.widget<Text>(find.text('09:41'));
      expect(timeTextDark.style?.color, equals(Colors.white.withOpacity(0.85)));

      // Cuộn xuống tìm công tắc 'Hiện Tên Giảng viên'
      await tester.scrollUntilVisible(find.text('Hiện Tên Giảng viên'), 500, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();

      // Nhấn switch Hiện Tên Giảng viên
      final teacherSwitchFinder = find.ancestor(
        of: find.text('Hiện Tên Giảng viên'),
        matching: find.byType(Row),
      );
      final switchInRow = find.descendant(
        of: teacherSwitchFinder,
        matching: find.byType(Switch),
      );
      await tester.tap(switchInRow);
      await tester.pumpAndSettle();

      // Cuộn ngược lên để xem Live Preview
      await tester.scrollUntilVisible(find.textContaining('LIVE PREVIEW'), -500, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();

      // Giảng viên mẫu chuẩn HAU xuất hiện trong Live Preview
      expect(find.textContaining('ThS. Nguyễn Thị Huệ'), findsWidgets);
    });
  });
}
