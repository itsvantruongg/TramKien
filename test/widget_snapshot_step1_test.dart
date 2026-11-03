import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';

void main() {
  group('1. Mô hình Session (Trục Kind & Status)', () {
    test('SessionKind phân định rõ class và exam', () {
      expect(SessionKind.fromValue('class'), SessionKind.classSession);
      expect(SessionKind.fromValue('exam'), SessionKind.examSession);
      expect(SessionKind.fromValue('EXAM'), SessionKind.examSession);
      expect(SessionKind.fromValue('other'), SessionKind.classSession);

      expect(SessionKind.classSession.value, 'class');
      expect(SessionKind.examSession.value, 'exam');
    });

    test('SessionStatus tính toán độc lập so với now (past, current, upcoming)', () {
      final start = DateTime.utc(2026, 10, 28, 2, 45); // 09:45 VN
      final end = DateTime.utc(2026, 10, 28, 4, 45); // 11:45 VN

      final sessionFixed = Session(
        id: 1,
        kind: SessionKind.examSession,
        subjectName: 'PPL NCKH',
        shortName: 'PPL',
        start: start,
        end: end,
        room: 'B205',
        colorIndex: 5,
      );

      // 1. Trước giờ bắt đầu -> upcoming
      final before = start.subtract(const Duration(minutes: 10));
      expect(sessionFixed.calculateStatus(before), SessionStatus.upcoming);

      // 2. Ngay mốc bắt đầu -> current
      expect(sessionFixed.calculateStatus(start), SessionStatus.current);

      // 3. Trong giờ học/thi -> current
      final mid = start.add(const Duration(minutes: 20)); // 10:05 VN
      expect(sessionFixed.calculateStatus(mid), SessionStatus.current);

      // 4. Ngay mốc kết thúc -> past (theo quy tắc end <= now)
      expect(sessionFixed.calculateStatus(end), SessionStatus.past);

      // 5. Sau mốc kết thúc -> past
      final after = end.add(const Duration(minutes: 15));
      expect(sessionFixed.calculateStatus(after), SessionStatus.past);
    });

    test('Tiến độ và số phút còn lại tính toán chính xác', () {
      final start = DateTime.utc(2026, 10, 28, 2, 45); // 09:45 VN
      final end = DateTime.utc(2026, 10, 28, 4, 45); // 11:45 VN (120 phút)

      final session = Session(
        id: 1,
        kind: SessionKind.examSession,
        subjectName: 'Thi PPL NCKH',
        shortName: 'PPL',
        start: start,
        end: end,
        room: 'B205',
        colorIndex: 0,
        endEstimated: false,
      );

      expect(session.durationMinutes, 120);

      // Tại 10:05 VN (đã qua 20 phút)
      final now1005 = start.add(const Duration(minutes: 20));
      final progress = session.calculateProgress(now1005);
      expect((progress * 100).toStringAsFixed(1), '16.7'); // ~16.7%
      expect(session.getRemainingMinutes(now1005), 100);

      // Ca thi có endEstimated = true -> ẩn tiến độ (progress = 0.0)
      final estimatedSession = session.copyWith(endEstimated: true);
      expect(estimatedSession.calculateProgress(now1005), 0.0);
    });

    test('Serialization to/from JSON bảo toàn 100% dữ liệu', () {
      final original = Session(
        id: 101,
        kind: SessionKind.classSession,
        subjectName: 'Lập trình Web',
        shortName: 'LT Web',
        start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 6, 55),
        end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 9, 20),
        room: 'P.301',
        teacher: 'Th. Hòa',
        examSeat: null,
        colorIndex: 2,
        endEstimated: false,
      );

      final json = original.toJson();
      expect(json['id'], 101);
      expect(json['kind'], 'class');
      expect(json['subject'], 'Lập trình Web');
      expect(json['short'], 'LT Web');
      expect(json['room'], 'P.301');
      expect(json['teacher'], 'Th. Hòa');
      expect(json['seat'], isNull);
      expect(json['color'], 2);
      expect(json['endEstimated'], false);

      final restored = Session.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.subjectName, original.subjectName);
      expect(restored.shortName, original.shortName);
      expect(restored.startMs, original.startMs);
      expect(restored.endMs, original.endMs);
      expect(restored.room, original.room);
      expect(restored.teacher, original.teacher);
      expect(restored.examSeat, original.examSeat);
      expect(restored.colorIndex, original.colorIndex);
      expect(restored.endEstimated, original.endEstimated);
    });
  });

  group('2. Thuật toán FNV-1a 32-bit băm màu (Mục 2.2)', () {
    test('Băm FNV-1a 32-bit là hàm thuần, xác định và bất biến', () {
      final h1 = WidgetHashUtils.fnv1a32('Lập trình Web');
      final h2 = WidgetHashUtils.fnv1a32('Lập trình Web');
      expect(h1, h2);

      // Tự động trim khoảng trắng đầu cuối
      final h3 = WidgetHashUtils.fnv1a32('   Lập trình Web \n\t');
      expect(h3, h1);
    });

    test('Kết quả colorIndex nằm chặt chẽ trong khoảng 0..7', () {
      final testSubjects = [
        'Lập trình Web',
        'Phương pháp luận nghiên cứu khoa học',
        'Cấu trúc dữ liệu và giải thuật 2',
        'Mạng máy tính',
        'Thể dục',
        'Đồ án CN',
        'Triết học Mác - Lênin',
        'Toán cao cấp 1',
        'Vật lý đại cương',
        'Tiếng Anh chuyên ngành',
        '',
      ];

      for (final s in testSubjects) {
        final color = WidgetHashUtils.calculateColorIndex(s);
        expect(color, inInclusiveRange(0, 7));
      }
    });

    test('Giá trị màu cố định cho các môn mẫu trong Spec', () {
      // Cố định để đảm bảo Widget Native và Dart luôn ánh xạ đồng bộ
      expect(WidgetHashUtils.calculateColorIndex('Lập trình Web'), 2);
      expect(WidgetHashUtils.calculateColorIndex('Phương pháp luận nghiên cứu khoa học'), 5);
      expect(WidgetHashUtils.calculateColorIndex('Cấu trúc dữ liệu và giải thuật 2'), 2);
      expect(WidgetHashUtils.calculateColorIndex('Mạng máy tính'), 3);
      expect(WidgetHashUtils.calculateColorIndex('Thể dục'), 6);
      expect(WidgetHashUtils.calculateColorIndex('Đồ án CN'), 5);
    });
  });

  group('3. Sinh shortName và Quy tắc Cắt tên dài (Mục 2.3 & AC-09)', () {
    test('Ưu tiên 1: Tên tự đặt từ ghi chú của sinh viên', () {
      final short = WidgetHashUtils.generateShortName(
        subjectName: 'Phương pháp luận nghiên cứu khoa học',
        note: 'Môn thầy Nam',
      );
      expect(short, 'Môn thầy Nam');
    });

    test('Ưu tiên 2: Tra cứu bảng viết tắt chuẩn HAU', () {
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Phương pháp luận nghiên cứu khoa học',
        ),
        'PPL NCKH',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Cấu trúc dữ liệu và giải thuật 2',
        ),
        'CTDL & GT 2',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Triết học Mác - Lênin',
        ),
        'Triết Mác - Lênin',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Lập trình Web',
        ),
        'LT Web',
      );
    });

    test('Ưu tiên 3: Acronym thông minh chuyển từ nối "và", "Và", "VÀ", "&" thành " & "', () {
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Kho dữ liệu và khai phá dữ liệu',
        ),
        'KDL & KPDL',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Kho dữ liệu Và khai phá dữ liệu',
        ),
        'KDL & KPDL',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'KHO DỮ LIỆU VÀ KHAI PHÁ DỮ LIỆU',
        ),
        'KDL & KPDL',
      );
      expect(
        WidgetHashUtils.generateShortName(
          subjectName: 'Kho dữ liệu & khai phá dữ liệu 2',
        ),
        'KDL & KPDL 2',
      );
    });

    test('Bảo tồn hậu tố phân biệt khi cắt giữa (Ellipsis Preservation)', () {
      // Môn có hậu tố số "2" -> Cắt ở giữa bảo tồn số 2
      const longWithSuffix = 'Cấu trúc dữ liệu và giải thuật 2';
      final formatted = WidgetHashUtils.formatWithEllipsisPreservation(
        longWithSuffix,
        maxLength: 24,
      );
      expect(formatted.endsWith(' 2'), isTrue);
      expect(formatted.contains('…'), isTrue);

      // Môn không có hậu tố -> Cắt ở cuối
      const longWithoutSuffix = 'Phương pháp luận nghiên cứu khoa học nâng cao';
      final formattedEnd = WidgetHashUtils.formatWithEllipsisPreservation(
        longWithoutSuffix,
        maxLength: 20,
      );
      expect(formattedEnd.endsWith('…'), isTrue);
      expect(formattedEnd.length, lessThanOrEqualTo(20));
    });
  });

  group('4. Bộ sinh Bản chụp Lịch thuần (Snapshot Generator)', () {
    test('Bung đầy đủ LichHoc và LichThi thành Sessions với múi giờ Asia/Ho_Chi_Minh', () {
      final lichHoc = [
        const LichHoc(
          tenHocPhan: 'Lập trình Web',
          soTinChi: 3,
          tenLopTinChi: 'CNTT1',
          thoiGian: '26/10/2026 - 02/11/2026',
          thu: 'Thứ 4',
          tiet: '1-3',
          phong: 'P.301',
          giaoVien: 'Th. Hòa',
          hocKy: 1,
          namHoc: '2026-2027',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      final lichThi = [
        const LichThi(
          tenMonHoc: 'Phương pháp luận nghiên cứu khoa học',
          ngayThi: '28/10/2026',
          gioBatDau: '09:45',
          gioKetThuc: '11:45',
          phong: 'B205',
          sooBaoDanh: '0123',
          hocKy: 1,
          namHoc: '2026-2027',
        ),
        const LichThi(
          tenMonHoc: 'Thi Vấn đáp',
          ngayThi: '14/10/2026',
          gioBatDau: '14:00',
          gioKetThuc: '', // Không có giờ kết thúc -> fallback 90p, endEstimated = true
          phong: 'B101',
          hocKy: 1,
          namHoc: '2026-2027',
        ),
      ];

      final snapshot = WidgetSnapshotGenerator.generateSnapshot(
        lichHocList: lichHoc,
        lichThiList: lichThi,
        generatedAt: DateTime.utc(2026, 10, 20),
      );

      expect(snapshot.version, 1);
      expect(snapshot.tz, 'Asia/Ho_Chi_Minh');

      // 26/10 đến 02/11 có 2 Thứ 4: ngày 28/10 và ngày 04/11 (04/11 > 02/11 nên chỉ có 1 ngày 28/10)
      // Tổng cộng: 1 buổi học + 2 buổi thi = 3 sessions
      expect(snapshot.sessions.length, 3);

      // Kiểm tra buổi học Lập trình Web ngày 28/10
      final webSession = snapshot.sessions.firstWhere((s) => s.subjectName == 'Lập trình Web');
      expect(webSession.kind, SessionKind.classSession);
      expect(webSession.room, 'P.301');
      expect(webSession.teacher, 'Th. Hòa');
      expect(webSession.endEstimated, isFalse);

      final webStartVn = WidgetTimeUtils.epochMsToVnDateTime(webSession.startMs);
      final webEndVn = WidgetTimeUtils.epochMsToVnDateTime(webSession.endMs);
      expect(webStartVn.hour, 6);
      expect(webStartVn.minute, 55);
      expect(webEndVn.hour, 9);
      expect(webEndVn.minute, 20);

      // Kiểm tra ca thi có giờ kết thúc
      final examSession = snapshot.sessions.firstWhere(
        (s) => s.subjectName == 'Phương pháp luận nghiên cứu khoa học',
      );
      expect(examSession.kind, SessionKind.examSession);
      expect(examSession.examSeat, '0123');
      expect(examSession.endEstimated, isFalse);

      final examStartVn = WidgetTimeUtils.epochMsToVnDateTime(examSession.startMs);
      final examEndVn = WidgetTimeUtils.epochMsToVnDateTime(examSession.endMs);
      expect(examStartVn.hour, 9);
      expect(examStartVn.minute, 45);
      expect(examEndVn.hour, 11);
      expect(examEndVn.minute, 45);

      // Kiểm tra ca thi không có giờ kết thúc -> fallback 90 phút & endEstimated = true
      final estimatedExam = snapshot.sessions.firstWhere((s) => s.subjectName == 'Thi Vấn đáp');
      expect(estimatedExam.endEstimated, isTrue);
      expect(estimatedExam.durationMinutes, 90);
    });

    test('Xử lý chính xác 100% các định dạng gio_thi thực tế theo Mục 4.1', () {
      final testCases = [
        (gioBatDau: '07H30-09H30', gioKetThuc: '', expectedStart: '07:30', expectedEnd: '09:30', estimated: false),
        (gioBatDau: '09h45-11h45', gioKetThuc: '', expectedStart: '09:45', expectedEnd: '11:45', estimated: false),
        (gioBatDau: '13H30-15H30', gioKetThuc: '', expectedStart: '13:30', expectedEnd: '15:30', estimated: false),
        (gioBatDau: '14H00', gioKetThuc: '', expectedStart: '14:00', expectedEnd: '15:30', estimated: true),
        (gioBatDau: '08h00 - 10h00', gioKetThuc: '', expectedStart: '08:00', expectedEnd: '10:00', estimated: false),
      ];

      for (int i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        final rawThi = LichThi(
          tenMonHoc: 'Môn thi $i',
          ngayThi: '28/10/2026',
          gioBatDau: tc.gioBatDau,
          gioKetThuc: tc.gioKetThuc,
          phong: 'P$i',
          hocKy: 1,
          namHoc: '2026-2027',
        );

        final snap = WidgetSnapshotGenerator.generateSnapshot(
          lichHocList: [],
          lichThiList: [rawThi],
          generatedAt: DateTime.utc(2026, 10, 20),
        );

        expect(snap.sessions.length, 1, reason: 'Failed for pattern: ${tc.gioBatDau}');
        final s = snap.sessions.first;
        expect(s.endEstimated, tc.estimated, reason: 'endEstimated mismatch for ${tc.gioBatDau}');

        final startVn = WidgetTimeUtils.epochMsToVnDateTime(s.startMs);
        final endVn = WidgetTimeUtils.epochMsToVnDateTime(s.endMs);

        final startStr = '${startVn.hour.toString().padLeft(2, '0')}:${startVn.minute.toString().padLeft(2, '0')}';
        final endStr = '${endVn.hour.toString().padLeft(2, '0')}:${endVn.minute.toString().padLeft(2, '0')}';

        expect(startStr, tc.expectedStart, reason: 'Start mismatch for ${tc.gioBatDau}');
        expect(endStr, tc.expectedEnd, reason: 'End mismatch for ${tc.gioBatDau}');
      }
    });
  });

  group('5. Cấu trúc JSON Snapshot & Quản lý File Lưu trữ', () {
    late Directory tempDir;
    late WidgetSnapshotStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('widget_snapshot_test_');
      storage = WidgetSnapshotStorage(customBaseDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Ghi và đọc bản chụp thành công từ file JSON (Atomic & Lossless)', () async {
      final sampleSnapshot = WidgetTestHarness.createSpecSampleSnapshot();

      // Lưu file
      final file = await storage.saveSnapshot(sampleSnapshot);
      expect(await file.exists(), isTrue);

      // Đọc file
      final readSnapshot = await storage.readSnapshot();
      expect(readSnapshot, isNotNull);
      expect(readSnapshot!.version, 1);
      expect(readSnapshot.tz, 'Asia/Ho_Chi_Minh');
      expect(readSnapshot.sessions.length, sampleSnapshot.sessions.length);

      // Kiểm tra môn đầu tiên
      expect(readSnapshot.sessions[0].subjectName, sampleSnapshot.sessions[0].subjectName);
    });

    test('Xử lý an toàn khi file chưa tồn tại -> trả về null, không throw', () async {
      final nonExistentStorage = WidgetSnapshotStorage(
        customBaseDir: Directory('${tempDir.path}/non_existent_subdir'),
      );
      final res = await nonExistentStorage.readSnapshot();
      expect(res, isNull);
    });

    test('Xử lý an toàn khi file bị hỏng (Syntax Error) -> trả về null, không crash', () async {
      final file = await storage.getSnapshotFile();
      await file.writeAsString('THIS IS CORRUPTED JSON GARBAGE { "version": ');

      final res = await storage.readSnapshot();
      expect(res, isNull);
    });

    test('Xử lý an toàn khi file có version không hỗ trợ -> coi như không hợp lệ', () async {
      final file = await storage.getSnapshotFile();
      await file.writeAsString(jsonEncode({
        'version': 999,
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
        'tz': 'Asia/Ho_Chi_Minh',
        'sessions': [],
      }));

      final res = await storage.readSnapshot();
      expect(res, isNull);
    });

    test('Xóa bản chụp khi đăng xuất hoặc đổi tài khoản', () async {
      final sampleSnapshot = WidgetTestHarness.createSpecSampleSnapshot();
      await storage.saveSnapshot(sampleSnapshot);
      expect(await storage.hasSnapshot(), isTrue);

      final deleted = await storage.deleteSnapshot();
      expect(deleted, isTrue);
      expect(await storage.hasSnapshot(), isFalse);
    });
  });

  group('6. Test Harness & Kiểm thử mốc Spec 28/10/2026 10:05', () {
    test('Xác thực toàn bộ kết quả mong đợi theo Mục 5.2 tại mốc 10:05', () {
      final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
      final mockNow = WidgetTestHarness.specMockNow;

      // 1. Kiểm tra Active Session tại 10:05
      final active = snapshot.getActiveSession(mockNow);
      expect(active, isNotNull);
      expect(active!.kind, SessionKind.examSession);
      expect(active.subjectName, 'Phương pháp luận nghiên cứu khoa học');
      expect(active.room, 'B205');
      expect(active.examSeat, '0123');
      expect(active.calculateStatus(mockNow), SessionStatus.current);

      // Tiến độ thi: 20 phút / 120 phút = 16.67%
      expect((active.calculateProgress(mockNow) * 100).toStringAsFixed(1), '16.7');
      expect(active.getRemainingMinutes(mockNow), 100);

      // 2. Các buổi học hôm nay (28/10): tổng 4 môn
      final todaySessions = snapshot.getTodaySessions(mockNow);
      expect(todaySessions.length, 4);

      // Môn đã qua: Tiết 1-3 Lập trình Web (kết thúc 09:20)
      final pastSessions = todaySessions
          .where((s) => s.calculateStatus(mockNow) == SessionStatus.past)
          .toList();
      expect(pastSessions.length, 1);
      expect(pastSessions.first.subjectName, 'Lập trình Web');

      // Môn còn lại hôm nay: 3 môn (1 đang thi, 2 sắp tới)
      final remainingSessions = snapshot.getRemainingTodaySessions(mockNow);
      expect(remainingSessions.length, 3);

      // Ca sắp tới kế tiếp: ưu tiên lịch thi (nếu chưa thi), hoặc môn sắp tới gần nhất
      final nextUpcoming = snapshot.getNextUpcomingSession(mockNow);
      expect(nextUpcoming, isNotNull);
      expect(nextUpcoming!.subjectName, 'Cấu trúc dữ liệu và giải thuật 2');

      // 3. Mốc đổi trạng thái trong ngày 28/10 (gồm giờ bắt đầu, kết thúc các ca và 00:00 ngày 29)
      final transitions = snapshot.getAllEventTimestampsForDay(mockNow);
      expect(transitions.length, greaterThan(4));
      // Mốc cuối cùng phải là 00:00 của ngày hôm sau
      final lastTransitionVn = WidgetTimeUtils.toVnDateTime(transitions.last);
      expect(lastTransitionVn.day, 29);
      expect(lastTransitionVn.hour, 0);
      expect(lastTransitionVn.minute, 0);
    });
  });

  group('7. Kiểm định AC-08 & Xóa bản chụp khi Đăng xuất (clearAllWidgetData)', () {
    test('AC-08: Quét mã nguồn logic widget Bước 1 không có mốc giờ cố định', () {
      final widgetLogicFiles = [
        File('lib/models/widget_session.dart'),
        File('lib/models/widget_schedule_snapshot.dart'),
        File('lib/services/widget/widget_hash_utils.dart'),
        File('lib/services/widget/widget_time_utils.dart'),
        File('lib/services/widget/widget_snapshot_generator.dart'),
        File('lib/services/widget/widget_snapshot_storage.dart'),
      ];

      final timePattern = RegExp(r'\b\d{1,2}:\d{2}\b');

      for (final file in widgetLogicFiles) {
        expect(file.existsSync(), isTrue, reason: 'File must exist: ${file.path}');
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // Bỏ qua dòng chú thích
          if (line.startsWith('//') || line.startsWith('///') || line.startsWith('*')) {
            continue;
          }
          final match = timePattern.firstMatch(line);
          expect(
            match,
            isNull,
            reason: 'Phát hiện mốc giờ cố định tại ${file.path}:${i + 1} -> "$line"',
          );
        }
      }
    });

    test('Xóa bản chụp và triggerNativeWidgetUpdate khi đăng xuất trong clearAllWidgetData', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Giả lập lưu file snapshot
      final tempDir = await Directory.systemTemp.createTemp('widget_logout_test_');
      final storage = WidgetSnapshotStorage(customBaseDir: tempDir);
      final sample = WidgetTestHarness.createSpecSampleSnapshot();
      final file = await storage.saveSnapshot(sample);
      expect(await file.exists(), isTrue);

      // Gọi clearAllWidgetData
      await WidgetDataSyncService.clearAllWidgetData(
        prefs: prefs,
        snapshotStorage: storage,
      );

      // Xác nhận file snapshot đã bị xóa
      expect(await file.exists(), isFalse);

      // Dọn dẹp
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
