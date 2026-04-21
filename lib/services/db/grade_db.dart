import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';
import '../database_service.dart';

class GradeDb {
  // ── ĐIỂM ─────────────────────────────────

  static Future<void> saveDiem(List<Map<String, dynamic>> list,
      {int? hocKy, String? namHoc, String? mssv}) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      for (final raw in list) {
        final resolvedMssv = mssv ?? raw['mssv']?.toString() ?? '';
        final resolvedNamHoc = raw['nam_hoc']?.toString() ??
            raw['namHoc']?.toString() ??
            namHoc ??
            '';
        final resolvedHocKy = raw['hoc_ky'] ?? raw['hocKy'] ?? hocKy ?? 1;
        final resolvedCourseCode = raw['course_code']?.toString() ??
            raw['maMonHoc']?.toString() ??
            raw['Đị ký hiệu']?.toString() ??
            '';
        final resolvedCourseName = raw['course_name']?.toString() ??
            raw['tenMonHoc']?.toString() ??
            raw['Tên học phần']?.toString() ??
            '';
        final resolvedCredits =
            raw['credits'] ?? raw['soTinChi'] ?? raw['Số tín chỉ'] ?? 0;

        if (resolvedCourseName.isEmpty || resolvedNamHoc.isEmpty) continue;

        final isPendingVote =
            raw['canVote'] == true || raw['status'] == 'pending_vote';
        final resolvedStatus = isPendingVote ? 'pending_vote' : 'completed';

        final item = <String, Object?>{
          'mssv': resolvedMssv,
          'course_code': resolvedCourseCode.isNotEmpty
              ? resolvedCourseCode
              : resolvedCourseName.substring(
                  0, resolvedCourseName.length.clamp(0, 10)),
          'course_name': resolvedCourseName,
          'credits': resolvedCredits,
          'coefficient': raw['coefficient'] ?? raw['Hệ số'],
          'component_score': raw['component_score']?.toString() ??
              raw['componentScore']?.toString() ??
              raw['Điểm thành phần']?.toString(),
          'exam_score': raw['exam_score']?.toString() ??
              raw['examScore']?.toString() ??
              raw['Điểm thi']?.toString(),
          'avg_grade':
              _parseDouble(raw['avg_grade'] ?? raw['avgGrade'] ?? raw['TBCHP']),
          'numeric_grade': _parseDouble(raw['numeric_grade'] ??
              raw['diemTongKet'] ??
              raw['avgGrade'] ??
              raw['Điểm số']),
          'letter_grade': raw['letter_grade']?.toString() ??
              raw['xepLoai']?.toString() ??
              raw['Điểm chữ']?.toString(),
          'is_elective':
              (raw['is_elective'] == 1 || raw['Môn tự chọn'] == '*') ? 1 : 0,
          'notes': raw['notes']?.toString() ?? raw['Ghi chú']?.toString(),
          'status': resolvedStatus,
          'nam_hoc': resolvedNamHoc,
          'hoc_ky': resolvedHocKy,
          'attempt': raw['attempt'] ?? 1,
        };

        if (isPendingVote) {
          // Môn cần vote: IGNORE để không đè lên bản ghi đã vote
          await txn.insert('student_grades', item,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        } else {
          // Môn đã có điểm: REPLACE để lấy dữ liệu mới nhất
          // Nhưng phải giữ nguyên status 'completed' nếu đã vote
          final existing = await txn.query(
            'student_grades',
            columns: ['status'],
            where:
                'mssv = ? AND course_code = ? AND nam_hoc = ? AND hoc_ky = ?',
            whereArgs: [
              resolvedMssv,
              item['course_code'],
              resolvedNamHoc,
              resolvedHocKy,
            ],
          );
          // Nếu DB đang là 'completed' (đã vote) → giữ 'completed'
          if (existing.isNotEmpty &&
              existing.first['status'] == 'completed' &&
              resolvedStatus == 'pending_vote') {
            item['status'] = 'completed';
          }
          await txn.insert('student_grades', item,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  // Helper parse double an toàn
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.tryParse(value.replaceAll(',', '.'));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<List<DiemMonHoc>> getDiem({int? hocKy, String? namHoc}) async {
    final d = await DatabaseService.db;
    final rows = await d.query('student_grades',
        where: hocKy != null ? 'hoc_ky = ? AND nam_hoc = ?' : null,
        whereArgs: hocKy != null ? [hocKy, namHoc] : null,
        orderBy: 'nam_hoc DESC, hoc_ky DESC');
    return rows.map(DiemMonHoc.fromMap).toList();
  }

  static Future<void> markDaVote(int diemId) async {
    final d = await DatabaseService.db;
    // Cập nhật status + xóa các giá trị placeholder "Vote"
    await d.update(
      'student_grades',
      {
        'status': 'completed',
        // Xóa placeholder "Vote" khỏi các trường điểm
        'exam_score': null,
        'letter_grade': null,
      },
      where: 'id = ? AND (exam_score = ? OR letter_grade = ?)',
      whereArgs: [diemId, 'Vote', 'Vote'],
    );
    // Fallback: nếu không có "Vote" literal, vẫn update status
    await d.update(
      'student_grades',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [diemId],
    );
  }

  // GPA tính từ SQLite — dùng numeric_grade thay diemHe4
  static Future<double> calculateGPA({int? hocKy, String? namHoc}) async {
    final d = await DatabaseService.db;
    String where;
    List<Object?> whereArgs;

    if (hocKy != null && namHoc != null) {
      where = 'status != ? AND hoc_ky = ? AND nam_hoc = ? '
          'AND (avg_grade IS NOT NULL OR numeric_grade IS NOT NULL)';
      whereArgs = ['pending_vote', hocKy, namHoc];
    } else {
      where = 'status != ? '
          'AND (avg_grade IS NOT NULL OR numeric_grade IS NOT NULL)';
      whereArgs = ['pending_vote'];
    }

    final rows =
        await d.query('student_grades', where: where, whereArgs: whereArgs);
    if (rows.isEmpty) return 0.0;

    double totalPts = 0;
    int totalCreds = 0;
    for (final row in rows) {
      // Ưu tiên avg_grade (TBCHP), fallback numeric_grade — đều thang 10
      final grade = (row['avg_grade'] as num?)?.toDouble() ??
          (row['numeric_grade'] as num?)?.toDouble() ??
          0.0;
      final credits = (row['credits'] as int?) ?? 0;
      if (grade > 0 && credits > 0) {
        totalPts += grade * credits;
        totalCreds += credits;
      }
    }
    return totalCreds > 0 ? totalPts / totalCreds : 0.0;
  }

  // Sửa totalCreditsEarned — thang 10 thì pass >= 4.0
  static Future<int> totalCreditsEarned() async {
    final d = await DatabaseService.db;
    final rows = await d.query('student_grades',
        where: "(avg_grade >= 4.0 OR numeric_grade >= 4.0) "
            "AND status != 'pending_vote' "
            "AND letter_grade NOT IN ('F')");
    return rows.fold<int>(
        0, (sum, row) => sum + ((row['credits'] as int?) ?? 0));
  }

  static Future<void> saveDiemSummary(DiemSummary summary) async {
    final d = await DatabaseService.db;
    await d.insert(
        'cache_meta',
        {
          'key': 'diem_summary',
          'data_hash': jsonEncode({
            'tbcTichLuyHe4': summary.tbcTichLuyHe4,
            'tbcTichLuyHe10': summary.tbcTichLuyHe10,
            'tbcHocTapHe4': summary.tbcHocTapHe4,
            'tbcHocTapHe10': summary.tbcHocTapHe10,
            'xepLoaiHe4': summary.xepLoaiHe4,
            'xepLoaiHe10': summary.xepLoaiHe10,
            'soTinChiTichLuy': summary.soTinChiTichLuy,
            'soTinChiTichLuyMax': summary.soTinChiTichLuyMax,
            'soTinChiHocTap': summary.soTinChiHocTap,
            'diemKhenThuong': summary.diemKhenThuong,
          }),
          'last_fetched': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Trả về GPA hệ 10 (và hệ 4) theo từng kỳ (cho biểu đồ)
  static Future<Map<String, double>> getGPAByKy() async {
    final d = await DatabaseService.db;
    final rows = await d.query('student_grades',
        where: 'avg_grade IS NOT NULL AND avg_grade > 0',
        orderBy: 'nam_hoc ASC, hoc_ky ASC');

    final Map<String, List<Map<String, Object?>>> grouped = {};
    for (final row in rows) {
      final key = '${row['nam_hoc']}_HK${row['hoc_ky']}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    final result = <String, double>{};
    for (final entry in grouped.entries) {
      double pts = 0;
      int creds = 0;
      for (final row in entry.value) {
        final grade = (row['avg_grade'] as num?)?.toDouble() ?? 0;
        final credits = (row['credits'] as int?) ?? 0;
        if (grade > 0 && credits > 0) {
          pts += grade * credits;
          creds += credits;
        }
      }
      if (creds > 0) result[entry.key] = pts / creds;
    }
    return result;
  }

  static double _he10ToHe4(double d10) {
    if (d10 >= 9.0) return 4.0;
    if (d10 >= 8.5) return 3.7;
    if (d10 >= 8.0) return 3.5;
    if (d10 >= 7.5) return 3.0;
    if (d10 >= 7.0) return 2.5;
    if (d10 >= 6.5) return 2.0;
    if (d10 >= 6.0) return 1.5;
    if (d10 >= 5.0) return 1.0;
    return 0.0;
  }

  // Thêm getGPAByKyHe4 — dùng numeric_grade (Điểm số hệ 4):
  static Future<Map<String, double>> getGPAByKyHe4() async {
    final d = await DatabaseService.db;
    // ← FIX: lấy cả rows có avg_grade để fallback convert
    final rows = await d.query('student_grades',
        where: 'avg_grade IS NOT NULL AND avg_grade > 0',
        orderBy: 'nam_hoc ASC, hoc_ky ASC');

    final Map<String, List<Map<String, Object?>>> grouped = {};
    for (final row in rows) {
      final key = '${row['nam_hoc']}_HK${row['hoc_ky']}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    final result = <String, double>{};
    for (final entry in grouped.entries) {
      double pts = 0;
      int creds = 0;
      for (final row in entry.value) {
        // Ưu tiên numeric_grade (hệ 4 thực), fallback convert từ avg_grade
        final grade4 = (row['numeric_grade'] as num?)?.toDouble();
        final grade10 = (row['avg_grade'] as num?)?.toDouble() ?? 0.0;
        final grade = (grade4 != null && grade4 > 0)
            ? grade4
            : _he10ToHe4(grade10); // ← FIX: convert thay vì bỏ qua
        final credits = (row['credits'] as int?) ?? 0;
        if (grade > 0 && credits > 0) {
          pts += grade * credits;
          creds += credits;
        }
      }
      if (creds > 0) result[entry.key] = pts / creds;
    }
    return result;
  }

  static Future<DiemSummary?> loadDiemSummary() async {
    try {
      final d = await DatabaseService.db;
      final rows = await d.query('cache_meta', where: "key = 'diem_summary'");
      if (rows.isEmpty || rows.first['data_hash'] == null) return null;
      final map =
          jsonDecode(rows.first['data_hash'] as String) as Map<String, dynamic>;
      return DiemSummary(
        tbcTichLuyHe4: (map['tbcTichLuyHe4'] as num?)?.toDouble(),
        tbcTichLuyHe10: (map['tbcTichLuyHe10'] as num?)?.toDouble(),
        tbcHocTapHe4: (map['tbcHocTapHe4'] as num?)?.toDouble(),
        tbcHocTapHe10: (map['tbcHocTapHe10'] as num?)?.toDouble(),
        xepLoaiHe4: map['xepLoaiHe4'] as String? ?? '',
        xepLoaiHe10: map['xepLoaiHe10'] as String? ?? '',
        soTinChiTichLuy:
            (map['soTinChiTichLuy'] as num?)?.toInt(), // ← fix cast
        soTinChiTichLuyMax:
            (map['soTinChiTichLuyMax'] as num?)?.toInt(), // ← fix cast
        soTinChiHocTap: (map['soTinChiHocTap'] as num?)?.toInt(), // ← fix cast
        diemKhenThuong: (map['diemKhenThuong'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('❌ loadDiemSummary error: $e'); // ← thêm log để debug
      return null;
    }
  }

  // Lấy môn cần vote (status = pending_vote)
  static Future<List<DiemMonHoc>> getDiemCanVote() async {
    final d = await DatabaseService.db;
    final rows =
        await d.query('student_grades', where: "status = 'pending_vote'");
    return rows.map(DiemMonHoc.fromMap).toList();
  }

  // ── ĐIỂM RÈN LUYỆN ───────────────────────
  static Future<void> saveTrainingPoints(
      List<Map<String, dynamic>> list) async {
    final d = await DatabaseService.db;
    await d.transaction((txn) async {
      await txn.delete('training_points');
      for (final raw in list) {
        await txn.insert(
            'training_points',
            {
              'nam_hoc': raw['nam_hoc'],
              'hoc_ky': raw['hoc_ky'],
              'diem': raw['diem'],
              'xep_loai': raw['xep_loai'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
