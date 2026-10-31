import 'dart:convert';

/// Tiện ích băm màu FNV-1a 32-bit và xử lý tên môn (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01)
class WidgetHashUtils {
  static const int fnvOffsetBasis = 0x811C9DC5;
  static const int fnvPrime = 0x01000193;

  /// Băm FNV-1a 32-bit chuẩn trên mảng byte UTF-8 của chuỗi [input.trim()]
  /// Bắt buộc ép tràn 32-bit & 0xFFFFFFFF sau mỗi bước nhân
  static int fnv1a32(String input) {
    final bytes = utf8.encode(input.trim());
    int hash = fnvOffsetBasis;
    for (final b in bytes) {
      hash = ((hash ^ b) * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Tính colorIndex (0..7) độc quyền ở tầng Dart từ tên học phần
  /// Khóa băm dùng chuỗi ten_hoc_phan.trim()
  static int calculateColorIndex(String tenHocPhan) {
    final hash = fnv1a32(tenHocPhan);
    return (hash & 0x7FFFFFFF) % 8;
  }

  /// Bảng viết tắt chuẩn các môn học tại HAU
  static const Map<String, String> hauStandardAbbreviations = {
    'phương pháp luận nghiên cứu khoa học': 'PPL NCKH',
    'cấu trúc dữ liệu và giải thuật 2': 'CTDL & GT 2',
    'cấu trúc dữ liệu và giải thuật 1': 'CTDL & GT 1',
    'cấu trúc dữ liệu và giải thuật': 'CTDL & GT',
    'triết học mác - lênin': 'Triết Mác - Lênin',
    'triết học mác-lênin': 'Triết Mác - Lênin',
    'kinh tế chính trị mác - lênin': 'KTCT Mác - Lênin',
    'kinh tế chính trị mác-lênin': 'KTCT Mác - Lênin',
    'chủ nghĩa xã hội khoa học': 'CNXHKH',
    'lịch sử đảng cộng sản việt nam': 'LS Đảng CSVN',
    'tư tưởng hồ chí minh': 'TT Hồ Chí Minh',
    'giáo dục thể chất': 'GDTC',
    'giáo dục quốc phòng': 'GDQP',
    'lập trình web': 'LT Web',
    'lập trình di động': 'LT Di động',
    'mạng máy tính': 'Mạng máy tính',
    'hệ điều hành': 'Hệ điều hành',
    'cơ sở dữ liệu': 'CSDL',
    'kỹ thuật đồ họa': 'KT Đồ họa',
    'trí tuệ nhân tạo': 'AI',
    'học máy': 'Học máy',
    'đồ án chuyên ngành': 'Đồ án CN',
    'đồ án cn': 'Đồ án CN',
    'đồ án tốt nghiệp': 'ĐATN',
    'thể dục': 'Thể dục',
  };

  /// Sinh shortName theo 4 thứ tự ưu tiên trong đặc tả (Mục 2.3):
  /// 1. Tên tự đặt của sinh viên (nếu có note hợp lệ)
  /// 2. Bảng viết tắt chuẩn các môn HAU
  /// 3. Chữ cái đầu mỗi từ viết hoa (kèm bảo tồn hậu tố)
  /// 4. Mã học phần / Tên lớp tín chỉ (nếu truyền vào)
  /// 5. Tên gốc rút gọn
  static String generateShortName({
    required String subjectName,
    String? note,
    String? classCode,
    String? courseCode,
  }) {
    // 1. Tên tự đặt của sinh viên nếu note ngắn gọn
    if (note != null && note.trim().isNotEmpty) {
      final trimmedNote = note.trim();
      if (trimmedNote.length <= 25 &&
          !trimmedNote.toLowerCase().contains('http') &&
          !trimmedNote.toLowerCase().startsWith('phòng') &&
          !trimmedNote.toLowerCase().startsWith('tự nhập:')) {
        return trimmedNote;
      }
    }

    final trimmedSubject = subjectName.trim();
    if (trimmedSubject.isEmpty) return '';

    // 2. Tra bảng viết tắt chuẩn HAU
    final normalized = trimmedSubject.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (hauStandardAbbreviations.containsKey(normalized)) {
      return hauStandardAbbreviations[normalized]!;
    }

    // Kiểm tra xem tên có chứa cụm từ chuẩn nào trong bảng không
    for (final entry in hauStandardAbbreviations.entries) {
      if (normalized == entry.key) {
        return entry.value;
      }
    }

    // 3. Chữ cái đầu mỗi từ viết hoa (Acronym)
    // Nếu tên môn dài (> 12 ký tự), tạo acronym
    if (trimmedSubject.length > 12) {
      final acronym = _buildAcronymWithSuffix(trimmedSubject);
      if (acronym.isNotEmpty && acronym.length <= 15) {
        return acronym;
      }
    }

    // 4. Mã học phần hoặc tên lớp tín chỉ nếu ngắn gọn
    if (courseCode != null &&
        courseCode.trim().isNotEmpty &&
        courseCode.trim().length <= 12) {
      return courseCode.trim();
    }
    if (classCode != null &&
        classCode.trim().isNotEmpty &&
        classCode.trim().length <= 12) {
      return classCode.trim();
    }

    return trimmedSubject;
  }

  /// Trích xuất chữ cái đầu mỗi từ viết hoa, bảo tồn số / chữ số La Mã ở cuối
  static String _buildAcronymWithSuffix(String name) {
    // Tách phần hậu tố phân biệt nếu có (ví dụ " 2", " II", " A")
    final suffixMatch = RegExp(r'\s+([0-9]+|[IVXLCDM]+|[A-Za-z])$').firstMatch(name);
    String core = name;
    String suffix = '';
    if (suffixMatch != null) {
      suffix = suffixMatch.group(0)!;
      core = name.substring(0, suffixMatch.start);
    }

    final words = core.split(RegExp(r'[\s\-_]+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= 1) return name;

    final buffer = StringBuffer();
    for (final w in words) {
      final firstChar = w[0].toUpperCase();
      buffer.write(firstChar);
    }

    if (suffix.isNotEmpty) {
      buffer.write(suffix);
    }
    return buffer.toString();
  }

  /// Quy tắc cắt tên dài bảo tồn hậu tố (Ellipsis Preservation - Mục 2.3 & AC-09)
  /// Nếu tên có hậu tố phân biệt (số 1, 2, La Mã I, II, III...) thì cắt ở giữa bằng "…"
  /// Ngược lại cắt ở cuối
  static String truncatePreserveSuffix(String name, {int maxLength = 24}) =>
      formatWithEllipsisPreservation(name, maxLength: maxLength);

  static String formatWithEllipsisPreservation(String name, {int maxLength = 24}) {
    final trimmed = name.trim();
    if (trimmed.length <= maxLength) return trimmed;

    // Tìm hậu tố phân biệt ở cuối chuỗi: số, La Mã, hoặc chữ cái đơn (ví dụ " 2", " II", " B")
    final suffixMatch = RegExp(
      r'(\s+(?:[0-9]+|[IVXLCDM]+|[A-Za-z]))$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (suffixMatch != null) {
      // Có hậu tố phân biệt -> Cắt ở giữa để bảo tồn hậu tố
      final suffix = suffixMatch.group(1)!;
      final remainingBudget = maxLength - 1 - suffix.length; // 1 ký tự cho "…"
      if (remainingBudget >= 6) {
        final leftBudget = (remainingBudget * 0.55).floor();
        final rightBudget = remainingBudget - leftBudget;

        final leftPart = trimmed.substring(0, leftBudget).trimRight();
        final beforeSuffix = trimmed.substring(0, suffixMatch.start);
        final rightStart = beforeSuffix.length - rightBudget;
        final rightPart = rightStart > leftBudget
            ? beforeSuffix.substring(rightStart).trimLeft()
            : '';

        if (rightPart.isNotEmpty) {
          return '$leftPart…$rightPart$suffix';
        } else {
          return '$leftPart…$suffix';
        }
      }
    }

    // Không có hậu tố phân biệt -> Cắt ở cuối
    return '${trimmed.substring(0, maxLength - 1).trimRight()}…';
  }
}
