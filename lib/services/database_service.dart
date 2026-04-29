import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'db/schedule_db.dart';
import 'db/grade_db.dart';
import 'db/finance_db.dart';

// Re-export for easier access
export 'db/schedule_db.dart';
export 'db/grade_db.dart';
export 'db/finance_db.dart';

class DatabaseService {
  static Database? _db;
  static const _version = 11;
  static String _currentMssv = '';
  static int _currentUserId = -1;

  // ── User Registry (mssv → userId) ─────────
  // admin → 0, các user khác tăng dần 1,2,3,...
  static const _kUserRegistry = 'user_registry_v1';
  static const _kNextUserId = 'user_next_id_v1';

  static Future<int> _getOrCreateUserId(String mssv) async {
    if (mssv == 'admin') return 0;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserRegistry) ?? '{}';
    // Parse thủ công vì không có dart:convert cũng được, nhưng dùng luôn
    // Lưu dưới dạng "mssv1=1,mssv2=2"
    final entries = raw.isEmpty || raw == '{}'
        ? <String, int>{}
        : Map.fromEntries(
            raw.split(',').where((e) => e.contains('=')).map((e) {
              final p = e.split('=');
              return MapEntry(p[0], int.tryParse(p[1]) ?? -1);
            }),
          );

    if (entries.containsKey(mssv)) return entries[mssv]!;

    // Tạo userId mới
    int nextId = prefs.getInt(_kNextUserId) ?? 1;
    entries[mssv] = nextId;
    await prefs.setInt(_kNextUserId, nextId + 1);
    await prefs.setString(_kUserRegistry,
        entries.entries.map((e) => '${e.key}=${e.value}').join(','));
    return nextId;
  }

  static Future<void> _removeUserFromRegistry(String mssv) async {
    if (mssv == 'admin' || mssv.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserRegistry) ?? '';
    if (raw.isEmpty) return;
    final entries = Map.fromEntries(
      raw.split(',').where((e) => e.contains('=')).map((e) {
        final p = e.split('=');
        return MapEntry(p[0], int.tryParse(p[1]) ?? -1);
      }),
    );
    entries.remove(mssv);
    await prefs.setString(_kUserRegistry,
        entries.entries.map((e) => '${e.key}=${e.value}').join(','));
  }

  static Future<void> setMssv(String mssv) async {
    if (_currentMssv != mssv) {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      _currentMssv = mssv;
      _currentUserId = mssv.isNotEmpty ? await _getOrCreateUserId(mssv) : -1;
    }
  }

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  // Sửa hàm _init(), thêm onUpgrade:
  static Future<Database> _init() async {
    // Mỗi user có 1 file DB riêng: schedify_uid0.db (admin), schedify_uid1.db, ...
    final uid = _currentUserId >= 0 ? _currentUserId : 0;
    final path = join(await getDatabasesPath(), 'schedify_uid$uid.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 3) {
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN coefficient INTEGER');
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN component_score TEXT');
          await db
              .execute('ALTER TABLE student_grades ADD COLUMN exam_score TEXT');
          await db
              .execute('ALTER TABLE student_grades ADD COLUMN avg_grade REAL');
        }
        if (oldV < 7) {
          await db.delete('cache_meta', where: "key = 'hoc_phi_all'");
          await db.delete('payment_receipts');
          await db.delete('fee_details');
          await db.delete('fee_summary');
        }
        if (oldV < 8) {
          // Xóa lịch học cũ (parse thiếu rows do không hỗ trợ rowspan)
          await db.delete('lich_hoc');
          await db.delete('cache_meta', where: "key = 'lich_hoc_hk'");
          // Xóa điểm cũ (chưa được lưu DB, chỉ có trong bộ nhớ)
          await db.delete('student_grades');
          await db.delete('cache_meta', where: "key = 'diem_all'");
        }
        if (oldV < 10) {
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN raw_avg_grade TEXT');
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN raw_numeric_grade TEXT');
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN raw_letter_grade TEXT');
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN is_overview INTEGER DEFAULT 0');
        }
        if (oldV < 11) {
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN raw_component_score TEXT');
          await db.execute(
              'ALTER TABLE student_grades ADD COLUMN raw_exam_score TEXT');
        }
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng Thông tin sinh viên
    await db.execute('''
      CREATE TABLE student (
        mssv TEXT PRIMARY KEY,
        ho_ten TEXT, ngay_sinh TEXT, gioi_tinh TEXT,
        chuyen_nganh TEXT, he_dao_tao TEXT, nien_khoa TEXT,
        khoa_hoc TEXT, cmnd TEXT, email TEXT, dien_thoai TEXT,
        que_quan TEXT, dia_chi_bao_tin TEXT, last_updated TEXT
      )
    ''');

    // 2. Bảng Lịch học (Giữ nguyên)
    await db.execute('''
      CREATE TABLE lich_hoc (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ten_hoc_phan TEXT, so_tin_chi INTEGER,
        ten_lop_tin_chi TEXT, thoi_gian TEXT,
        thu TEXT, tiet TEXT, phong TEXT, giao_vien TEXT,
        hoc_ky INTEGER, nam_hoc TEXT, dot_hoc INTEGER,
        chuyen_nganh TEXT, last_updated TEXT
      )
    ''');

    // 3. Bảng Lịch thi (Giữ nguyên)
    await db.execute('''
    CREATE TABLE lich_thi (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ma_hoc_phan TEXT, ten_hoc_phan TEXT, so_tin_chi INTEGER,
      ngay_thi TEXT, ca_thi TEXT, gio_thi TEXT,
      lan_thi INTEGER, dot_thi INTEGER,
      so_bao_danh TEXT, phong_thi TEXT, hinh_thuc TEXT, hoan_thi TEXT,
      hoc_ky INTEGER, nam_hoc TEXT, last_updated TEXT
    )
  ''');

    // 4. Bảng Điểm (Đã sửa để khớp với Excel: thêm he_so, tbchp)
    await db.execute('''
      CREATE TABLE student_grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mssv TEXT NOT NULL,
        
        -- Thông tin môn học
        course_code TEXT NOT NULL,      -- Ký hiệu (TC2611)
        course_name TEXT NOT NULL,      -- Tên học phần
        credits INTEGER NOT NULL,       -- Số tín chỉ
        coefficient INTEGER,            -- Hệ số (mới thêm)
        
        -- Điểm chi tiết
        component_score TEXT,           -- Điểm thành phần (QT : 7.1)
        exam_score TEXT,                -- Điểm thi (chuỗi thô)
        avg_grade REAL,                 -- TBCHP (mới thêm)
        numeric_grade REAL,             -- Điểm số (đã quy đổi)
        letter_grade TEXT,              -- Điểm chữ (A, B, C...)
        
        -- Dữ liệu gốc (hỗ trợ hiển thị 'F | B')
        raw_avg_grade TEXT,
        raw_numeric_grade TEXT,
        raw_letter_grade TEXT,
        is_overview INTEGER DEFAULT 0,  -- Điểm từ trang Tổng quan
        raw_component_score TEXT,       -- Điểm thành phần gốc
        raw_exam_score TEXT,            -- Điểm thi gốc
        
        -- Phân loại & Trạng thái
        is_elective INTEGER DEFAULT 0,  -- Môn tự chọn
        notes TEXT,                     -- Ghi chú
        status TEXT DEFAULT 'completed',
        
        -- Metadata
        nam_hoc TEXT NOT NULL,          -- 2023-2024
        hoc_ky INTEGER NOT NULL,        -- 1 hoặc 2
        attempt INTEGER DEFAULT 1,      -- Lần học
        
        UNIQUE(mssv, course_code, attempt, nam_hoc, hoc_ky)
    );
    ''');

    // 5. Bảng Chương trình đào tạo (Đã sửa: thêm tổng tiết, id môn)
    await db.execute('''
      CREATE TABLE curriculum_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_code TEXT NOT NULL UNIQUE,
        course_name TEXT NOT NULL,
        credits INTEGER,
        knowledge_block TEXT,           -- Khối kiến thức
        semester_index INTEGER,         -- Kỳ thứ (planned_semester)
        total_periods INTEGER,          -- Tổng số tiết (mới thêm)
        subject_id TEXT,                -- ID môn (mới thêm)
        is_elective INTEGER DEFAULT 0,
        status TEXT DEFAULT 'planned'
      )
    ''');

    // 6. Bảng Điểm rèn luyện (Mới)
    await db.execute('''
      CREATE TABLE training_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nam_hoc TEXT NOT NULL,
        hoc_ky INTEGER,                 -- NULL nếu là tổng cả năm
        diem INTEGER,
        xep_loai TEXT,
        UNIQUE(nam_hoc, hoc_ky)
      )
    ''');

    // 7. Bảng Kết quả đăng ký (Mới)
    await db.execute('''
      CREATE TABLE registration_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hoc_ky INTEGER NOT NULL,
        nam_hoc TEXT NOT NULL,
        ten_hoc_phan TEXT NOT NULL,
        lop_hoc_phan TEXT,
        so_tin_chi INTEGER,
        tu_chon INTEGER DEFAULT 0
      )
    ''');

    // 8. Các bảng Học phí (Giữ nguyên logic cũ đã có)
    await db.execute('''
      CREATE TABLE payment_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        so_phieu TEXT UNIQUE NOT NULL,
        nam_hoc TEXT NOT NULL,
        hoc_ky INTEGER NOT NULL,
        lan_thu INTEGER DEFAULT 1,
        dot_thu INTEGER DEFAULT 1,
        ngay_thu TEXT NOT NULL,
        tong_tien_phieu REAL NOT NULL,
        trang_thai TEXT DEFAULT 'Đã nộp',
        last_updated TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        so_phieu TEXT NOT NULL,
        ten_hoc_phan TEXT NOT NULL,
        loai_khoan TEXT DEFAULT 'Học phí',
        so_tien_phai_nop REAL NOT NULL,
        so_tien_mien_giam REAL DEFAULT 0,
        so_tien_da_nop REAL NOT NULL,
        so_tien_thua_thieu REAL DEFAULT 0,
        trang_thai TEXT DEFAULT 'Đã nộp',
        nam_hoc TEXT NOT NULL,
        hoc_ky INTEGER NOT NULL,
        ngay_nop TEXT,
        FOREIGN KEY (so_phieu) REFERENCES payment_receipts(so_phieu) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_summary (
        id INTEGER PRIMARY KEY,
        nam_hoc TEXT NOT NULL,
        hoc_ky INTEGER NOT NULL,
        muc_hoc_phi REAL DEFAULT 0,
        mien_giam REAL DEFAULT 0,
        phai_nop REAL DEFAULT 0,
        da_nop REAL DEFAULT 0,
        thua_thieu REAL DEFAULT 0,
        UNIQUE(nam_hoc, hoc_ky)
      )
    ''');

    // 9. Cache & Session
    await db.execute('''
      CREATE TABLE cache_meta (
        key TEXT PRIMARY KEY,
        data_hash TEXT,
        last_fetched TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE session (
        id INTEGER PRIMARY KEY,
        mssv TEXT,
        session_id TEXT,
        created_at TEXT
      )
    ''');

    // Tạo Index tối ưu
    await db.execute(
        'CREATE INDEX idx_grades_semester ON student_grades(nam_hoc, hoc_ky)');
    await db.execute(
        'CREATE INDEX idx_grades_course ON student_grades(course_code)');
    await db.execute(
        'CREATE INDEX idx_schedule_time ON lich_hoc(hoc_ky, nam_hoc, thu)');
    await db
        .execute('CREATE INDEX idx_exam_time ON lich_thi(ngay_thi, ca_thi)');
  }

  // ── STUDENT ──────────────────────────────

  static Future<void> saveStudent(Student s) async {
    final d = await db;
    await d.insert('student', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Student?> getStudent(String mssv) async {
    final d = await db;
    final rows = await d.query('student', where: 'mssv = ?', whereArgs: [mssv]);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  // ── CACHE META ────────────────────────────

  static Future<void> updateCacheMeta(String key, String hash) async {
    final d = await db;
    await d.insert(
        'cache_meta',
        {
          'key': key,
          'data_hash': hash,
          'last_fetched': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<CacheMeta?> getCacheMeta(String key) async {
    final d = await db;
    final rows =
        await d.query('cache_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : CacheMeta.fromMap(rows.first);
  }

  static Future<bool> isStale(String key, Duration ttl) async {
    final meta = await getCacheMeta(key);
    if (meta == null) return true;
    return meta.isStale(ttl);
  }

  // ── CLEAR ALL (dùng khi muốn xóa nội dung, không xóa file) ──

  static Future<void> clearAll() async {
    final d = await db;
    await d.transaction((txn) async {
      for (final table in [
        'student',
        'lich_hoc',
        'lich_thi',
        'student_grades',
        'curriculum_courses',
        'payment_receipts',
        'fee_details',
        'fee_summary',
        'training_points',
        'registration_results',
        'cache_meta',
        'session'
      ]) {
        await txn.delete(table);
      }
    });
  }

  // ── DELETE USER DB (gọi khi logout để xóa toàn bộ file DB của user đó) ──
  static Future<void> deleteCurrentUserDb() async {
    final mssv = _currentMssv;
    final uid = _currentUserId;
    if (uid < 0) return;

    // Đóng DB trước
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    // Admin (uid=0): KHÔNG xóa file, chỉ đóng và reset state
    if (uid == 0) {
      print('⚠️ Admin DB được bảo vệ, không xóa khi logout.');
      _currentMssv = '';
      _currentUserId = -1;
      return;
    }

    // User thường: xóa hẳn file
    final path = join(await getDatabasesPath(), 'schedify_uid$uid.db');
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('🗑️ Đã xóa DB của userId=$uid (mssv=$mssv)');
    }

    // Xóa khỏi registry
    await _removeUserFromRegistry(mssv);

    _currentMssv = '';
    _currentUserId = -1;
  }

  // ── SEED ADMIN DATA (nạp mock data vào DB admin nếu chưa có) ──
  // Gọi được nhiều lần (idempotent) — chỉ insert nếu bảng student rỗng
  static Future<bool> isAdminSeeded() async {
    final d = await db;
    final rows = await d.query('student', limit: 1);
    return rows.isNotEmpty;
  }

  // ── KẾT QUẢ ĐĂNG KÝ ──────────────────────
  static Future<void> saveRegistrationResults(
      List<Map<String, dynamic>> list) async {
    final d = await db;
    await d.transaction((txn) async {
      // Xóa theo năm học để tránh trùng lặp
      if (list.isNotEmpty && list.first.containsKey('nam_hoc')) {
        final String? namHoc = list.first['nam_hoc']?.toString();
        if (namHoc != null) {
          await txn.delete('registration_results',
              where: 'nam_hoc = ?', whereArgs: [namHoc]);
        }
      }

      for (final raw in list) {
        await txn.insert(
            'registration_results',
            {
              'hoc_ky': raw['Học kỳ'] ?? raw['hoc_ky'],
              'nam_hoc': raw['Năm học'] ?? raw['nam_hoc'],
              'ten_hoc_phan': raw['Tên học phần'] ?? raw['ten_hoc_phan'],
              'lop_hoc_phan': raw['Lớp học phần'] ?? raw['lop_hoc_phan'],
              'so_tin_chi': raw['Số tín chỉ'] ?? raw['so_tin_chi'],
              'tu_chon': raw['Tự chọn'] == '*' ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── HELPER ────────────────────────────────

  // Helper parse double an toàn (used by GradeDb)
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
}
