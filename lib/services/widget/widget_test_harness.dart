import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import 'widget_hash_utils.dart';
import 'widget_time_utils.dart';

/// Bộ Test Harness & Dữ liệu mẫu kiểm thử trường hợp biên theo Mục 5 SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01
class WidgetTestHarness {
  /// Mốc thời gian kiểm thử chuẩn theo đặc tả: 28/10/2026 10:05 (Giờ Việt Nam)
  static DateTime get specMockNow =>
      WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 10, 5);

  /// Tạo bản chụp chứa bộ dữ liệu mẫu kiểm thử trường hợp biên (Bảng 5.1)
  static WidgetScheduleSnapshot createSpecSampleSnapshot({DateTime? generatedAt}) {
    final genTime = generatedAt ?? WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 6, 0);
    final sessions = <Session>[];
    int nextId = 100;

    // 14/10/2026: 1 ca thi 14h00, 90p mặc định, endEstimated = true
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.examSession,
      subjectName: 'Kiểm thử phần mềm',
      shortName: 'KTPM',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 14, 14, 0),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 14, 15, 30),
      room: 'B101',
      teacher: null,
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Kiểm thử phần mềm'),
      endEstimated: true,
    ));

    // T2 26/10/2026: 3 ca học (Tiết 1-3, 4-6, 8-10)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Cơ sở dữ liệu',
      shortName: 'CSDL',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 6, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 9, 20),
      room: 'P.101',
      teacher: 'Th. Tuấn',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Cơ sở dữ liệu'),
      endEstimated: false,
    ));
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Hệ điều hành',
      shortName: 'Hệ điều hành',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 9, 30),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 11, 55),
      room: 'P.101',
      teacher: 'Cô Lan',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Hệ điều hành'),
      endEstimated: false,
    ));
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Kỹ thuật đồ họa',
      shortName: 'KT Đồ họa',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 12, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 26, 15, 25),
      room: 'P.101',
      teacher: 'Th. Hùng',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Kỹ thuật đồ họa'),
      endEstimated: false,
    ));

    // T3 27/10/2026: 1 ca học (Tiết 1-3)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Trí tuệ nhân tạo',
      shortName: 'AI',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 27, 6, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 27, 9, 20),
      room: 'P.102',
      teacher: 'Th. Minh',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Trí tuệ nhân tạo'),
      endEstimated: false,
    ));

    // T4 28/10/2026 (Ngày mốc kiểm thử chính 10:05):
    // 1) Tiết 1–3: Lập trình Web (06:55–09:20) -> past
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Lập trình Web',
      shortName: 'LT Web',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 6, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 9, 20),
      room: 'P.301',
      teacher: 'Th. Hòa',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Lập trình Web'),
      endEstimated: false,
    ));

    // 2) 09h45-11h45: Phương pháp luận nghiên cứu khoa học (exam, 120p, endEstimated = false) -> current tại 10:05
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.examSession,
      subjectName: 'Phương pháp luận nghiên cứu khoa học',
      shortName: 'PPL NCKH',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 9, 45),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 11, 45),
      room: 'B205',
      teacher: null,
      examSeat: '0123',
      colorIndex: WidgetHashUtils.calculateColorIndex('Phương pháp luận nghiên cứu khoa học'),
      endEstimated: false,
    ));

    // 3) Tiết 8–10: Cấu trúc dữ liệu và giải thuật 2 (12:55–15:25) -> upcoming
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Cấu trúc dữ liệu và giải thuật 2',
      shortName: 'CTDL & GT 2',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 12, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 15, 25),
      room: 'P.102',
      teacher: 'Cô Mai',
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Cấu trúc dữ liệu và giải thuật 2'),
      endEstimated: false,
    ));

    // 4) Tiết 11–12: Mạng máy tính (15:30–17:05) -> upcoming (+N môn)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Mạng máy tính',
      shortName: 'Mạng máy tính',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 15, 30),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 28, 17, 5),
      room: 'P.204',
      teacher: null,
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Mạng máy tính'),
      endEstimated: false,
    ));

    // T5 29/10/2026:
    // 1) Tiết 1–3: Mạng máy tính (06:55–09:20)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Mạng máy tính',
      shortName: 'Mạng máy tính',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 29, 6, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 29, 9, 20),
      room: 'P.204',
      teacher: null,
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Mạng máy tính'),
      endEstimated: false,
    ));
    // 2) Tiết 8–10: Thể dục (12:55–15:25)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Thể dục',
      shortName: 'Thể dục',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 29, 12, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 29, 15, 25),
      room: 'Sân A',
      teacher: null,
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Thể dục'),
      endEstimated: false,
    ));

    // T6 30/10/2026:
    // Tiết 8–10: Đồ án CN (12:55–15:25)
    sessions.add(Session(
      id: nextId++,
      kind: SessionKind.classSession,
      subjectName: 'Đồ án CN',
      shortName: 'Đồ án CN',
      start: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 30, 12, 55),
      end: WidgetTimeUtils.vnComponentsToDateTime(2026, 10, 30, 15, 25),
      room: 'Lab3',
      teacher: null,
      examSeat: null,
      colorIndex: WidgetHashUtils.calculateColorIndex('Đồ án CN'),
      endEstimated: false,
    ));

    // Sắp xếp thứ tự thời gian tăng dần
    sessions.sort((a, b) => a.startMs.compareTo(b.startMs));

    return WidgetScheduleSnapshot(
      version: 1,
      generatedAt: genTime.millisecondsSinceEpoch,
      tz: 'Asia/Ho_Chi_Minh',
      sessions: sessions,
    );
  }
}
