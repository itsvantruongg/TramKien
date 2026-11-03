import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';
import '../../models/widget_session.dart';
import '../../models/widget_schedule_snapshot.dart';
import '../database_service.dart';
import 'widget_hash_utils.dart';
import 'widget_time_utils.dart';

/// Hàm thuần sinh bản chụp lịch (Snapshot Generator) theo SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01
class WidgetSnapshotGenerator {
  /// Thời lượng ca thi mặc định khi DB không có giờ kết thúc (90 phút)
  static const Duration kDefaultExamDuration = Duration(minutes: 90);

  /// Hàm thuần sinh bản chụp từ danh sách LichHoc và LichThi
  static WidgetScheduleSnapshot generateSnapshot({
    required List<LichHoc> lichHocList,
    required List<LichThi> lichThiList,
    DateTime? generatedAt,
  }) {
    final nowMs = (generatedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final sessions = <Session>[];
    int nextId = 1;

    // ── Xây dựng Bảng màu định danh tự động trong học kỳ (Dynamic Subject Color Registry) ──
    // Hoàn toàn tự động bằng thuật toán, không hardcode bất kỳ tên môn nào:
    final uniqueSubjects = lichHocList
        .map((h) => h.tenHocPhan.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final subjectColorMap = <String, int>{};
    for (int i = 0; i < uniqueSubjects.length; i++) {
      subjectColorMap[uniqueSubjects[i]] = i % 8;
    }

    final uniqueExamSubjects = lichThiList
        .map((t) => t.tenMonHoc.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final examColorMap = <String, int>{};
    for (int i = 0; i < uniqueExamSubjects.length; i++) {
      examColorMap[uniqueExamSubjects[i]] = i % 4; // 4 token màu ấm phân biệt
    }

    // ── 1. Bung các buổi học từ LichHoc ──
    for (final hoc in lichHocList) {
      final subjectName = hoc.tenHocPhan.trim();
      if (subjectName.isEmpty) continue;

      final colorIndex = subjectColorMap[subjectName] ??
          WidgetHashUtils.calculateColorIndex(subjectName);
      final shortName = WidgetHashUtils.generateShortName(
        subjectName: subjectName,
        note: hoc.note,
        classCode: hoc.tenLopTinChi,
      );

      // Map giờ bắt đầu và kết thúc từ tietMap
      final startPeriod = hoc.tietBatDau;
      final tietTimes = LichHoc.tietMap[startPeriod];
      final gioBatDauStr = tietTimes?.$1 ?? hoc.gioHoc;
      final gioKetThucStr = hoc.gioKetThuc;

      var startTimeParts = _parseHourMinute(gioBatDauStr);
      if (startTimeParts == null) {
        if (startPeriod > 0) {
          final h = 6 + (startPeriod * 50) ~/ 60;
          final m = (startPeriod * 50) % 60;
          startTimeParts = (hour: h.clamp(6, 21), minute: m.clamp(0, 59));
        } else {
          startTimeParts = (hour: 7, minute: 0);
        }
      }

      var endTimeParts = _parseHourMinute(gioKetThucStr);
      if (endTimeParts == null) {
        final totalMinutes = startTimeParts.hour * 60 + startTimeParts.minute + 120;
        final endH = (totalMinutes ~/ 60).clamp(0, 23);
        final endM = totalMinutes % 60;
        endTimeParts = (hour: endH, minute: endM);
      }

      // Phân tích thứ và dải thời gian
      final targetWeekday = WidgetTimeUtils.parseThuToWeekday(hoc.thu);
      if (targetWeekday == null) continue;

      var range = WidgetTimeUtils.parseDateRange(hoc.thoiGian);
      if (range == null) {
        // Fallback an toàn: Dải thời gian 180 ngày quanh generatedAt để không bao giờ bỏ sót môn học
        final baseDate = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);
        final fallbackStart = baseDate.subtract(const Duration(days: 60));
        final fallbackEnd = baseDate.add(const Duration(days: 120));
        range = (
          start: DateTime.utc(fallbackStart.year, fallbackStart.month, fallbackStart.day),
          end: DateTime.utc(fallbackEnd.year, fallbackEnd.month, fallbackEnd.day),
        );
      }

      // Duyệt qua từng ngày trong dải thoiGian
      var currentDay = range.start;
      final endDay = range.end;

      while (!currentDay.isAfter(endDay)) {
        if (currentDay.weekday == targetWeekday) {
          final startMs = WidgetTimeUtils.vnComponentsToEpochMs(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            startTimeParts.hour,
            startTimeParts.minute,
          );
          final endMs = WidgetTimeUtils.vnComponentsToEpochMs(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            endTimeParts.hour,
            endTimeParts.minute,
          );

          sessions.add(Session(
            id: nextId++,
            kind: SessionKind.classSession,
            subjectName: subjectName,
            shortName: shortName,
            start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
            end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
            room: hoc.phong.trim(),
            teacher: hoc.giaoVien.trim().isNotEmpty ? hoc.giaoVien.trim() : null,
            examSeat: null,
            colorIndex: colorIndex,
            endEstimated: false,
          ));
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    // ── 2. Bung các buổi thi từ LichThi ──
    for (final thi in lichThiList) {
      final subjectName = thi.tenMonHoc.trim();
      if (subjectName.isEmpty) continue;

      final colorIndex = examColorMap[subjectName] ?? 0;
      final shortName = WidgetHashUtils.generateShortName(
        subjectName: subjectName,
        note: thi.note,
        courseCode: thi.maMonHoc,
      );

      final dateParts = WidgetTimeUtils.parseVnDate(thi.ngayThi);
      if (dateParts == null) continue;

      // Giờ thi
      String startStr = thi.gioBatDau;
      String endStr = thi.gioKetThuc;

      var startHM = _parseHourMinute(startStr);
      if (startHM == null && startStr.isNotEmpty) {
        final parsedStart = LichThi.parseGioBatDau(startStr);
        if (parsedStart.isNotEmpty) {
          startHM = _parseHourMinute(parsedStart);
          if (endStr.isEmpty) {
            endStr = LichThi.parseGioKetThuc(startStr);
          }
        }
      }

      // Fallback an toàn cho lịch thi thủ công hoặc chưa có giờ thi để không bao giờ bị drop
      if (startHM == null) {
        final caLower = thi.caThi.toLowerCase();
        if (caLower.contains('chiều') || caLower.contains('chieu') || caLower.contains('ca 2') || caLower == '2') {
          startHM = (hour: 13, minute: 30);
        } else if (caLower.contains('tối') || caLower.contains('toi') || caLower.contains('ca 3') || caLower == '3') {
          startHM = (hour: 18, minute: 0);
        } else {
          startHM = (hour: 7, minute: 30);
        }
      }

      final startMs = WidgetTimeUtils.vnComponentsToEpochMs(
        dateParts.year,
        dateParts.month,
        dateParts.day,
        startHM.hour,
        startHM.minute,
      );

      int endMs;
      bool endEstimated = false;

      final endHM = _parseHourMinute(endStr);
      if (endHM != null) {
        endMs = WidgetTimeUtils.vnComponentsToEpochMs(
          dateParts.year,
          dateParts.month,
          dateParts.day,
          endHM.hour,
          endHM.minute,
        );
        endEstimated = false;
      } else {
        // Fallback kDefaultExamDuration (90 phút) khi không có giờ kết thúc
        endMs = startMs + kDefaultExamDuration.inMilliseconds;
        endEstimated = true;
      }

      sessions.add(Session(
        id: nextId++,
        kind: SessionKind.examSession,
        subjectName: subjectName,
        shortName: shortName,
        start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
        room: thi.phong.trim(),
        teacher: null,
        examSeat: thi.sooBaoDanh.trim().isNotEmpty ? thi.sooBaoDanh.trim() : null,
        colorIndex: colorIndex,
        endEstimated: endEstimated,
      ));
    }

    // ── 3. Khử trùng giờ (Conflict Resolution): Lịch thi ưu tiên cao hơn lịch học ──
    // Nếu có lịch thi trùng khoảng thời gian với lịch học trong cùng một ngày,
    // lịch học đó sẽ nhường chỗ cho kỳ thi để đảm bảo không xảy ra đè ca.
    final examSessions = sessions.where((s) => s.kind == SessionKind.examSession).toList();
    if (examSessions.isNotEmpty) {
      sessions.removeWhere((classS) {
        if (classS.kind != SessionKind.classSession) return false;
        return examSessions.any((examS) =>
            classS.startMs < examS.endMs && classS.endMs > examS.startMs);
      });
    }

    // ── 4. Sắp xếp thứ tự thời gian tăng dần ──
    sessions.sort((a, b) {
      final startCmp = a.startMs.compareTo(b.startMs);
      if (startCmp != 0) return startCmp;
      return a.endMs.compareTo(b.endMs);
    });

    return WidgetScheduleSnapshot(
      version: WidgetScheduleSnapshot.currentVersion,
      generatedAt: nowMs,
      tz: WidgetScheduleSnapshot.defaultTimeZone,
      sessions: sessions,
    );
  }

  /// Trích xuất toàn bộ dữ liệu từ SQLite ScheduleDb và sinh bản chụp
  static Future<WidgetScheduleSnapshot> generateSnapshotFromDb({
    DatabaseExecutor? db,
    DateTime? generatedAt,
  }) async {
    final d = db ?? await DatabaseService.db;

    final hocRows = await d.query('lich_hoc', orderBy: 'thu ASC, tiet ASC');
    final thiRows = await d.query('lich_thi', orderBy: 'ngay_thi ASC');

    final lichHocList = hocRows.map(LichHoc.fromMap).toList();
    lichHocList.sort((a, b) {
      final thuCmp = a.thuSo.compareTo(b.thuSo);
      if (thuCmp != 0) return thuCmp;
      return a.tietBatDau.compareTo(b.tietBatDau);
    });
    final lichThiList = thiRows.map(LichThi.fromMap).toList();

    return generateSnapshot(
      lichHocList: lichHocList,
      lichThiList: lichThiList,
      generatedAt: generatedAt,
    );
  }

  static ({int hour, int minute})? _parseHourMinute(String timeStr) {
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2})[:Hh\s](\d{2})$').firstMatch(trimmed);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null) {
        return (hour: h, minute: m);
      }
    }
    return null;
  }
}
