/// Tiện ích xử lý múi giờ Việt Nam (UTC+7, Asia/Ho_Chi_Minh) cho Widget Lịch học
class WidgetTimeUtils {
  static const String timeZoneId = 'Asia/Ho_Chi_Minh';
  static const Duration vnOffset = Duration(hours: 7);

  /// Chuyển đổi các thành phần ngày giờ tại Việt Nam sang epoch milliseconds
  static int vnComponentsToEpochMs(
    int year,
    int month,
    int day,
    int hour,
    int minute, [
    int second = 0,
    int millisecond = 0,
  ]) {
    final utcEquiv = DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
    ).subtract(vnOffset);
    return utcEquiv.millisecondsSinceEpoch;
  }

  /// Chuyển đổi các thành phần ngày giờ tại Việt Nam sang đối tượng DateTime (UTC tương đương)
  static DateTime vnComponentsToDateTime(
    int year,
    int month,
    int day,
    int hour,
    int minute, [
    int second = 0,
    int millisecond = 0,
  ]) {
    return DateTime.fromMillisecondsSinceEpoch(
      vnComponentsToEpochMs(year, month, day, hour, minute, second, millisecond),
      isUtc: true,
    );
  }

  /// Lấy ngày giờ hiển thị theo giờ Việt Nam từ epoch milliseconds
  /// Kết quả là DateTime có year, month, day, hour, minute khớp 100% với giờ tại Việt Nam
  static DateTime epochMsToVnDateTime(int epochMs) {
    final utc = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    return utc.add(vnOffset);
  }

  /// Lấy ngày giờ hiển thị theo giờ Việt Nam từ đối tượng DateTime bất kỳ
  static DateTime toVnDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return utc.add(vnOffset);
  }

  /// Phân tích chuỗi ngày định dạng dd/MM/yyyy hoặc d/M/yyyy sang các thành phần (year, month, day)
  static ({int year, int month, int day})? parseVnDate(String dateStr) {
    final trimmed = dateStr.trim();
    if (trimmed.isEmpty) return null;

    final dmyMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
    if (dmyMatch != null) {
      final d = int.tryParse(dmyMatch.group(1)!);
      final m = int.tryParse(dmyMatch.group(2)!);
      final y = int.tryParse(dmyMatch.group(3)!);
      if (d != null && m != null && y != null) {
        return (year: y, month: m, day: d);
      }
    }

    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(trimmed);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!);
      final m = int.tryParse(isoMatch.group(2)!);
      final d = int.tryParse(isoMatch.group(3)!);
      if (d != null && m != null && y != null) {
        return (year: y, month: m, day: d);
      }
    }

    return null;
  }

  /// Phân tích dải ngày trong chuỗi thoiGian của LichHoc (ví dụ: "26/10/2026 - 20/12/2026")
  static ({DateTime start, DateTime end})? parseDateRange(String thoiGian) {
    final matches = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})')
        .allMatches(thoiGian)
        .toList();

    if (matches.isEmpty) return null;

    final first = parseVnDate(matches[0].group(0)!);
    if (first == null) return null;

    final start = DateTime.utc(first.year, first.month, first.day);

    if (matches.length >= 2) {
      final second = parseVnDate(matches[1].group(0)!);
      if (second != null) {
        final end = DateTime.utc(second.year, second.month, second.day);
        return (start: start, end: end);
      }
    }

    return (start: start, end: start);
  }

  /// Chuyển đổi chuỗi thứ ("Thứ 2".."Thứ 7", "Thứ 8", "Chủ nhật", "CN") sang mã weekday của Dart (1 = Thứ Hai, 7 = Chủ Nhật)
  static int? parseThuToWeekday(String thu) {
    final lower = thu.trim().toLowerCase();
    if (lower.isEmpty) return null;

    if (lower.contains('chủ nhật') ||
        lower.contains('chu nhat') ||
        lower == 'cn') {
      return DateTime.sunday; // 7
    }

    final match = RegExp(r'\d+').firstMatch(lower);
    if (match != null) {
      final num = int.tryParse(match.group(0)!);
      if (num != null) {
        if (num >= 2 && num <= 7) {
          // Thứ 2 -> 1, Thứ 3 -> 2, ..., Thứ 7 -> 6
          return num - 1;
        }
        if (num == 8) {
          return DateTime.sunday; // 7
        }
      }
    }

    return null;
  }

  /// Kiểm tra 2 mốc thời gian có cùng rơi vào 1 ngày tại Việt Nam hay không
  static bool isSameVnDay(DateTime a, DateTime b) {
    final vnA = toVnDateTime(a);
    final vnB = toVnDateTime(b);
    return vnA.year == vnB.year && vnA.month == vnB.month && vnA.day == vnB.day;
  }

  /// Lấy mốc 00:00:00 đầu ngày hôm sau tại Việt Nam (dùng cho mốc đổi trạng thái widget)
  static DateTime nextVnMidnight(DateTime dt) {
    final vn = toVnDateTime(dt);
    final nextDay = DateTime.utc(vn.year, vn.month, vn.day).add(const Duration(days: 1));
    return vnComponentsToDateTime(nextDay.year, nextDay.month, nextDay.day, 0, 0);
  }

  /// Định dạng giờ phút HH:mm theo giờ Việt Nam
  static String formatTimeHHmm(DateTime dt) {
    final vn = toVnDateTime(dt);
    final h = vn.hour.toString().padLeft(2, '0');
    final m = vn.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Viết tắt thứ tiếng Việt (T2, T3, T4, T5, T6, T7, CN)
  static String formatWeekdayAbbr(DateTime dt) {
    final vn = toVnDateTime(dt);
    switch (vn.weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
      default:
        return 'CN';
    }
  }

  /// Định dạng ngày dd/MM theo giờ Việt Nam
  static String formatVnDateDdMm(DateTime dt) {
    final vn = toVnDateTime(dt);
    final d = vn.day.toString().padLeft(2, '0');
    final m = vn.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  /// Định dạng ngày ISO yyyy-MM-dd theo giờ Việt Nam (cho Deep Link URL)
  static String formatVnDateIso(DateTime dt) {
    final vn = toVnDateTime(dt);
    final y = vn.year.toString().padLeft(4, '0');
    final m = vn.month.toString().padLeft(2, '0');
    final d = vn.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
