/// Loại phiên học/thi (Trục 1 của Mô hình Session theo SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01)
enum SessionKind {
  classSession('class'),
  examSession('exam');

  final String value;
  const SessionKind(this.value);

  static SessionKind fromValue(String value) {
    if (value.toLowerCase() == 'exam') return SessionKind.examSession;
    return SessionKind.classSession;
  }
}

/// Trạng thái thời gian thực của phiên (Trục 2 của Mô hình Session)
enum SessionStatus {
  past,
  current,
  upcoming;

  static SessionStatus fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'past':
        return SessionStatus.past;
      case 'current':
        return SessionStatus.current;
      case 'upcoming':
      default:
        return SessionStatus.upcoming;
    }
  }
}

/// Mô hình Session chuẩn hóa độc lập hai trục: Trạng thái & Loại phiên
class Session {
  final int id;
  final SessionKind kind;
  final String subjectName;
  final String shortName;
  final DateTime start;
  final DateTime end;
  final String room;
  final String? teacher;
  final String? examSeat;
  final int colorIndex;
  final bool endEstimated;

  const Session({
    required this.id,
    required this.kind,
    required this.subjectName,
    required this.shortName,
    required this.start,
    required this.end,
    required this.room,
    this.teacher,
    this.examSeat,
    required this.colorIndex,
    this.endEstimated = false,
  });

  /// Tính trạng thái thời gian thực dựa vào mốc thời gian [now]
  /// Quy tắc:
  /// - past: khi end <= now
  /// - current: khi start <= now < end
  /// - upcoming: khi start > now
  SessionStatus calculateStatus(DateTime now) {
    if (!end.isAfter(now)) return SessionStatus.past;
    if (!start.isAfter(now) && end.isAfter(now)) return SessionStatus.current;
    return SessionStatus.upcoming;
  }

  int get startMs => start.millisecondsSinceEpoch;
  int get endMs => end.millisecondsSinceEpoch;

  /// Tổng thời lượng phiên (phút)
  int get durationMinutes {
    final diff = end.difference(start).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Tiến độ hoàn thành (0.0 đến 1.0) tại mốc [now]
  double calculateProgress(DateTime now) {
    if (endEstimated) return 0.0;
    final total = endMs - startMs;
    if (total <= 0) return 0.0;
    final elapsed = now.millisecondsSinceEpoch - startMs;
    if (elapsed <= 0) return 0.0;
    if (elapsed >= total) return 1.0;
    return elapsed / total;
  }

  /// Số phút còn lại tính tới khi kết thúc phiên tại mốc [now]
  int getRemainingMinutes(DateTime now) {
    final diff = end.difference(now).inMinutes;
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.value,
        'subject': subjectName,
        'short': shortName,
        'startMs': startMs,
        'endMs': endMs,
        'room': room,
        'teacher': teacher,
        'seat': examSeat,
        'color': colorIndex,
        'endEstimated': endEstimated,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    final startMs = json['startMs'] is int
        ? json['startMs'] as int
        : int.tryParse(json['startMs']?.toString() ?? '0') ?? 0;
    final endMs = json['endMs'] is int
        ? json['endMs'] as int
        : int.tryParse(json['endMs']?.toString() ?? '0') ?? 0;

    return Session(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      kind: SessionKind.fromValue(json['kind'] as String? ?? 'class'),
      subjectName: (json['subject'] ?? json['subjectName'] ?? '').toString(),
      shortName: (json['short'] ?? json['shortName'] ?? json['subject'] ?? '')
          .toString(),
      start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
      room: (json['room'] ?? '').toString(),
      teacher: json['teacher'] as String?,
      examSeat: (json['seat'] ?? json['examSeat']) as String?,
      colorIndex: json['color'] is int
          ? json['color'] as int
          : int.tryParse(json['color']?.toString() ?? '0') ?? 0,
      endEstimated: json['endEstimated'] == true,
    );
  }

  Session copyWith({
    int? id,
    SessionKind? kind,
    String? subjectName,
    String? shortName,
    DateTime? start,
    DateTime? end,
    String? room,
    String? teacher,
    String? examSeat,
    int? colorIndex,
    bool? endEstimated,
  }) {
    return Session(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      subjectName: subjectName ?? this.subjectName,
      shortName: shortName ?? this.shortName,
      start: start ?? this.start,
      end: end ?? this.end,
      room: room ?? this.room,
      teacher: teacher ?? this.teacher,
      examSeat: examSeat ?? this.examSeat,
      colorIndex: colorIndex ?? this.colorIndex,
      endEstimated: endEstimated ?? this.endEstimated,
    );
  }

  @override
  String toString() =>
      'Session(id: $id, kind: ${kind.value}, subject: $subjectName, short: $shortName, room: $room, startMs: $startMs, endMs: $endMs, color: $colorIndex, endEstimated: $endEstimated)';
}
