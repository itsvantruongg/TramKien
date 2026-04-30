// ════════════════════════════════════════
// models/student.dart
// ════════════════════════════════════════

class Student {
  final String mssv;
  final String hoTen;
  final String ngaySinh;
  final String gioiTinh;
  final String chuyenNganh;
  final String heDaoTao;
  final String nienKhoa;
  final String khoaHoc;
  final String cmnd;
  final String email;
  final String dienThoai;
  final String queQuan;
  final String diaChiBaoTin;
  final DateTime? lastUpdated;

  const Student({
    required this.mssv,
    required this.hoTen,
    this.ngaySinh = '',
    this.gioiTinh = '',
    this.chuyenNganh = '',
    this.heDaoTao = '',
    this.nienKhoa = '',
    this.khoaHoc = '',
    this.cmnd = '',
    this.email = '',
    this.dienThoai = '',
    this.queQuan = '',
    this.diaChiBaoTin = '',
    this.lastUpdated,
  });

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        mssv: m['mssv'] ?? '',
        hoTen: m['ho_ten'] ?? '',
        ngaySinh: m['ngay_sinh'] ?? '',
        gioiTinh: m['gioi_tinh'] ?? '',
        chuyenNganh: m['chuyen_nganh'] ?? '',
        heDaoTao: m['he_dao_tao'] ?? '',
        nienKhoa: m['nien_khoa'] ?? '',
        khoaHoc: m['khoa_hoc'] ?? '',
        cmnd: m['cmnd'] ?? '',
        email: m['email'] ?? '',
        dienThoai: m['dien_thoai'] ?? '',
        queQuan: m['que_quan'] ?? '',
        diaChiBaoTin: m['dia_chi_bao_tin'] ?? '',
        lastUpdated: m['last_updated'] != null
            ? DateTime.tryParse(m['last_updated'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        'mssv': mssv,
        'ho_ten': hoTen,
        'ngay_sinh': ngaySinh,
        'gioi_tinh': gioiTinh,
        'chuyen_nganh': chuyenNganh,
        'he_dao_tao': heDaoTao,
        'nien_khoa': nienKhoa,
        'khoa_hoc': khoaHoc,
        'cmnd': cmnd,
        'email': email,
        'dien_thoai': dienThoai,
        'que_quan': queQuan,
        'dia_chi_bao_tin': diaChiBaoTin,
        'last_updated': lastUpdated?.toIso8601String(),
      };
}

// ════════════════════════════════════════
// models/lich_hoc.dart
// ════════════════════════════════════════

class LichHoc {
  final int? id;
  final String tenHocPhan;
  final int soTinChi;
  final String tenLopTinChi;
  final String thoiGian;
  final String thu;
  final String tiet;
  final String phong;
  final String giaoVien;
  final int hocKy;
  final String namHoc;
  final int dotHoc;
  final String chuyenNganh;
  final DateTime? lastUpdated;
  final String note;
  final bool isManual;

  const LichHoc({
    this.id,
    required this.tenHocPhan,
    required this.soTinChi,
    required this.tenLopTinChi,
    required this.thoiGian,
    required this.thu,
    required this.tiet,
    required this.phong,
    required this.giaoVien,
    required this.hocKy,
    required this.namHoc,
    required this.dotHoc,
    required this.chuyenNganh,
    this.lastUpdated,
    this.note = '',
    this.isManual = false,
  });

  factory LichHoc.fromMap(Map<String, dynamic> m) => LichHoc(
        id: m['id'],
        tenHocPhan: m['ten_hoc_phan'] ?? '',
        soTinChi: m['so_tin_chi'] is int
            ? m['so_tin_chi']
            : int.tryParse(m['so_tin_chi'].toString()) ?? 0,
        tenLopTinChi: m['ten_lop_tin_chi'] ?? '',
        thoiGian: m['thoi_gian'] ?? '',
        thu: m['thu'] ?? '',
        tiet: m['tiet'] ?? '',
        phong: m['phong'] ?? '',
        giaoVien: m['giao_vien'] ?? '',
        hocKy: m['hoc_ky'] is int
            ? m['hoc_ky']
            : int.tryParse(m['hoc_ky'].toString()) ?? 1,
        namHoc: m['nam_hoc'] ?? '',
        dotHoc: m['dot_hoc'] is int
            ? m['dot_hoc']
            : int.tryParse(m['dot_hoc'].toString()) ?? 1,
        chuyenNganh: m['chuyen_nganh'] ?? '',
        lastUpdated: m['last_updated'] != null
            ? DateTime.tryParse(m['last_updated'])
            : null,
        note: m['note'] ?? '',
        isManual: (m['is_manual'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ten_hoc_phan': tenHocPhan,
        'so_tin_chi': soTinChi,
        'ten_lop_tin_chi': tenLopTinChi,
        'thoi_gian': thoiGian,
        'thu': thu,
        'tiet': tiet,
        'phong': phong,
        'giao_vien': giaoVien,
        'hoc_ky': hocKy,
        'nam_hoc': namHoc,
        'dot_hoc': dotHoc,
        'chuyen_nganh': chuyenNganh,
        'last_updated':
            lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'note': note,
        'is_manual': isManual ? 1 : 0,
      };

  // Lấy thứ số (2-8) từ chuỗi "Thứ 4"
  int get thuSo {
    final match = RegExp(r'\d+').firstMatch(thu);
    final result = match != null ? int.parse(match.group(0)!) : 0;
    if (thu.isNotEmpty && result == 0) {
      print('⚠️ WARN: Cannot parse thuSo from "$thu" - returning 0');
    }
    return result;
  }

  // Lấy tiết bắt đầu
  int get tietBatDau {
    final match = RegExp(r'\d+').firstMatch(tiet);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  // Map tiết → giờ học
  static const _tietMap = {
    1: ('06:55', '07:40'),
    2: ('07:45', '08:30'),
    3: ('08:35', '09:20'),
    4: ('09:30', '10:15'),
    5: ('10:20', '11:05'),
    6: ('11:10', '11:55'),
    7: ('12:05', '12:50'),
    8: ('12:55', '13:40'),
    9: ('13:45', '14:30'),
    10: ('14:40', '15:25'),
    11: ('15:30', '16:15'),
    12: ('16:20', '17:05'),
  };

// Giờ bắt đầu của tiết đầu tiên
  String get gioHoc => _tietMap[tietBatDau]?.$1 ?? tiet;

// Giờ kết thúc: lấy tiết cuối cùng trong chuỗi tiet
// Ví dụ tiet = "1-3" → tiết cuối = 3 → 09:20
  String get gioKetThuc {
    // Parse tiết cuối từ chuỗi kiểu "1-3", "4", "5-6"
    final nums = RegExp(r'\d+')
        .allMatches(tiet)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    final lastTiet = nums.isNotEmpty ? nums.last : tietBatDau;
    return _tietMap[lastTiet]?.$2 ?? '';
  }

// Hiển thị đầy đủ "06:55 - 09:20"
  String get gioHocFull =>
      gioKetThuc.isNotEmpty ? '$gioHoc - $gioKetThuc' : gioHoc;

  LichHoc copyWith({String? note}) {
    return LichHoc(
      id: id,
      tenHocPhan: tenHocPhan,
      soTinChi: soTinChi,
      tenLopTinChi: tenLopTinChi,
      thoiGian: thoiGian,
      thu: thu,
      tiet: tiet,
      phong: phong,
      giaoVien: giaoVien,
      hocKy: hocKy,
      namHoc: namHoc,
      dotHoc: dotHoc,
      chuyenNganh: chuyenNganh,
      lastUpdated: lastUpdated,
      note: note ?? this.note,
      isManual: isManual,
    );
  }
}

// ════════════════════════════════════════
// models/lich_thi.dart
// ════════════════════════════════════════

class LichThi {
  final int? id;
  final String tenMonHoc;
  final String maMonHoc; // Mã học phần (mới)
  final int soTinChi; // Số tín chỉ (mới)
  final String ngayThi;
  final String caThi; // Sáng/Chiều/Tối (mới)
  final String gioBatDau;
  final String gioKetThuc;
  final int? lanThi; // Lần thi (mới)
  final int? dotThi; // Đợt thi (mới)
  final String sooBaoDanh; // Số báo danh
  final String phong; // Phòng thi
  final String hinhThucThi; // Hình thức thi
  final String? hoanThi; // Trạng thái hoãn (mới)
  final int hocKy;
  final String namHoc;
  final DateTime? lastUpdated;
  final String note;
  final bool isManual;

  const LichThi({
    this.id,
    required this.tenMonHoc,
    this.maMonHoc = '',
    this.soTinChi = 0,
    required this.ngayThi,
    this.caThi = '',
    this.gioBatDau = '',
    this.gioKetThuc = '',
    this.lanThi,
    this.dotThi,
    this.sooBaoDanh = '',
    this.phong = '',
    this.hinhThucThi = '',
    this.hoanThi,
    required this.hocKy,
    required this.namHoc,
    this.lastUpdated,
    this.note = '',
    this.isManual = false,
  });

  factory LichThi.fromMap(Map<String, dynamic> m) => LichThi(
        id: m['id'],
        tenMonHoc: m['ten_hoc_phan'] ?? '',
        maMonHoc: m['ma_hoc_phan'] ?? '',
        soTinChi: m['so_tin_chi'] is int
            ? m['so_tin_chi']
            : int.tryParse(m['so_tin_chi']?.toString() ?? '0') ?? 0,
        ngayThi: m['ngay_thi'] ?? '',
        caThi: m['ca_thi'] ?? '',
        gioBatDau: parseGioBatDau(m['gio_thi'] ?? ''),
        gioKetThuc: parseGioKetThuc(m['gio_thi'] ?? ''),
        lanThi: m['lan_thi'] is int
            ? m['lan_thi']
            : int.tryParse(m['lan_thi']?.toString() ?? ''),
        dotThi: m['dot_thi'] is int
            ? m['dot_thi']
            : int.tryParse(m['dot_thi']?.toString() ?? ''),
        sooBaoDanh: m['so_bao_danh'] ?? '',
        phong: m['phong_thi'] ?? '',
        hinhThucThi: m['hinh_thuc'] ?? '',
        hoanThi: m['hoan_thi'],
        hocKy: m['hoc_ky'] is int
            ? m['hoc_ky']
            : int.tryParse(m['hoc_ky'].toString()) ?? 1,
        namHoc: m['nam_hoc'] ?? '',
        lastUpdated: m['last_updated'] != null
            ? DateTime.tryParse(m['last_updated'])
            : null,
        note: m['note'] ?? '',
        isManual: (m['is_manual'] as int?) == 1,
      );

// "15H00-17H00" → "15:00"
  static String parseGioBatDau(String gioThi) {
    final match = RegExp(r'(\d{1,2})H(\d{2})').firstMatch(gioThi);
    if (match == null) return '';
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }

  static String parseGioKetThuc(String gioThi) {
    final matches = RegExp(r'(\d{1,2})H(\d{2})').allMatches(gioThi).toList();
    if (matches.length < 2) return '';
    final m = matches[1];
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ma_hoc_phan': maMonHoc,
        'ten_hoc_phan': tenMonHoc,
        'so_tin_chi': soTinChi,
        'ngay_thi': ngayThi,
        'ca_thi': caThi,
        'gio_thi': gioKetThuc.isNotEmpty
            ? '${gioBatDau.replaceAll(':', 'H')}-${gioKetThuc.replaceAll(':', 'H')}'
            : gioBatDau,
        'lan_thi': lanThi,
        'dot_thi': dotThi,
        'so_bao_danh': sooBaoDanh,
        'phong_thi': phong,
        'hinh_thuc': hinhThucThi,
        'hoan_thi': hoanThi,
        'hoc_ky': hocKy,
        'nam_hoc': namHoc,
        'last_updated':
            lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'note': note,
        'is_manual': isManual ? 1 : 0,
      };

  LichThi copyWith({String? note}) {
    return LichThi(
      id: id,
      tenMonHoc: tenMonHoc,
      maMonHoc: maMonHoc,
      soTinChi: soTinChi,
      ngayThi: ngayThi,
      caThi: caThi,
      gioBatDau: gioBatDau,
      gioKetThuc: gioKetThuc,
      lanThi: lanThi,
      dotThi: dotThi,
      sooBaoDanh: sooBaoDanh,
      phong: phong,
      hinhThucThi: hinhThucThi,
      hoanThi: hoanThi,
      hocKy: hocKy,
      namHoc: namHoc,
      lastUpdated: lastUpdated,
      note: note ?? this.note,
      isManual: isManual,
    );
  }

  DateTime? get ngayThiDate {

    try {
      final parts = ngayThi.split('/');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  int get daysUntilExam {
    final date = ngayThiDate;
    if (date == null) return 999;
    return date.difference(DateTime.now()).inDays;
  }
}

// ════════════════════════════════════════
// models/diem.dart
// ════════════════════════════════════════

class DiemMonHoc {
  final int? id;
  final String tenMonHoc;
  final String maMonHoc;
  final int soTinChi;
  final int? coefficient; // Hệ số (mới)
  final String? componentScore; // Điểm thành phần (mới)
  final String? examScore; // Điểm thi (mới)
  final double? avgGrade; // TBCHP (mới)
  final double? diemTongKet; // Điểm số (quy đổi)
  final String? xepLoai; // Điểm chữ
  final String? rawAvgGrade; // TBCHP gốc (ví dụ: '1.4 | 8')
  final String? rawDiemSo; // Điểm số gốc (ví dụ: '3 | 4')
  final String? rawXepLoai; // Điểm chữ gốc (ví dụ: 'F | B')
  final String? rawComponentScore; // Điểm thành phần gốc (ví dụ: 'QT: 7 | 9')
  final String? rawExamScore;      // Điểm thi gốc (ví dụ: '5 | 8')
  final int hocKy;
  final String namHoc;
  final bool isElective; // Môn tự chọn
  final bool canVote; // Môn cần vote mới xem được điểm
  final DateTime? lastUpdated;

  const DiemMonHoc({
    this.id,
    required this.tenMonHoc,
    this.maMonHoc = '',
    required this.soTinChi,
    this.coefficient,
    this.componentScore,
    this.examScore,
    this.avgGrade,
    this.diemTongKet,
    this.xepLoai,
    this.rawAvgGrade,
    this.rawDiemSo,
    this.rawXepLoai,
    this.rawComponentScore,
    this.rawExamScore,
    required this.hocKy,
    required this.namHoc,
    this.isElective = false,
    this.canVote = false,
    this.lastUpdated,
  });

  factory DiemMonHoc.fromMap(Map<String, dynamic> m) => DiemMonHoc(
        id: m['id'],
        tenMonHoc: m['course_name'] ?? '',
        maMonHoc: m['course_code'] ?? '',
        soTinChi: m['credits'] is int
            ? m['credits']
            : int.tryParse(m['credits'].toString()) ?? 0,
        coefficient: m['coefficient'] is int
            ? m['coefficient']
            : int.tryParse(m['coefficient']?.toString() ?? ''),
        componentScore: m['component_score'],
        examScore: m['exam_score'],
        avgGrade: m['avg_grade'] is double
            ? m['avg_grade']
            : (m['avg_grade'] != null
                ? double.tryParse(m['avg_grade'].toString())
                : null),
        diemTongKet: m['numeric_grade'] is double
            ? m['numeric_grade']
            : (m['numeric_grade'] != null
                ? double.tryParse(m['numeric_grade'].toString())
                : null),
        xepLoai: m['letter_grade'],
        rawAvgGrade: m['raw_avg_grade'],
        rawDiemSo: m['raw_numeric_grade'],
        rawXepLoai: m['raw_letter_grade'],
        rawComponentScore: m['raw_component_score'],
        rawExamScore: m['raw_exam_score'],
        hocKy: m['hoc_ky'] is int
            ? m['hoc_ky']
            : int.tryParse(m['hoc_ky'].toString()) ?? 1,
        namHoc: m['nam_hoc'] ?? '',
        isElective: (m['is_elective'] as int?) == 1,
        canVote: m['status'] == 'pending_vote',
        lastUpdated: m['last_updated'] != null
            ? DateTime.tryParse(m['last_updated'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'course_name': tenMonHoc,
        'course_code': maMonHoc,
        'credits': soTinChi,
        'coefficient': coefficient,
        'component_score': componentScore,
        'exam_score': examScore,
        'avg_grade': avgGrade,
        'numeric_grade': diemTongKet,
        'letter_grade': xepLoai,
        'raw_avg_grade': rawAvgGrade,
        'raw_numeric_grade': rawDiemSo,
        'raw_letter_grade': rawXepLoai,
        'raw_component_score': rawComponentScore,
        'raw_exam_score': rawExamScore,
        'is_elective': isElective ? 1 : 0,
        'status': canVote ? 'pending_vote' : 'completed',
        'hoc_ky': hocKy,
        'nam_hoc': namHoc,
      };

  String get xepLoaiDisplay {
    if (diemTongKet == null) return '--';
    final d = diemTongKet!;
    if (d >= 9.0) return 'A+';
    if (d >= 8.5) return 'A';
    if (d >= 8.0) return 'B+';
    if (d >= 7.0) return 'B';
    if (d >= 6.5) return 'C+';
    if (d >= 5.5) return 'C';
    if (d >= 5.0) return 'D+';
    if (d >= 4.0) return 'D';
    return 'F';
  }

  double get diemHe4 {
    if (diemTongKet == null) return 0;
    final d = diemTongKet!;
    if (d >= 9.0) return 4.0;
    if (d >= 8.5) return 4.0;
    if (d >= 8.0) return 3.5;
    if (d >= 7.0) return 3.0;
    if (d >= 6.5) return 2.5;
    if (d >= 5.5) return 2.0;
    if (d >= 5.0) return 1.5;
    if (d >= 4.0) return 1.0;
    return 0.0;
  }
}

// ════════════════════════════════════════
// models/hoc_phi.dart
// ════════════════════════════════════════

class HocPhi {
  final int? id;
  final String tenKhoanThu;
  final double soTien;
  final String trangThai; // 'Đã đóng' | 'Chưa đóng'
  final String ngayDong;
  final int hocKy;
  final String namHoc;
  final DateTime? lastUpdated;

  const HocPhi({
    this.id,
    required this.tenKhoanThu,
    required this.soTien,
    required this.trangThai,
    this.ngayDong = '',
    required this.hocKy,
    required this.namHoc,
    this.lastUpdated,
  });

  factory HocPhi.fromMap(Map<String, dynamic> m) => HocPhi(
        id: m['id'],
        tenKhoanThu: m['ten_khoan_thu'] ?? '',
        soTien: m['so_tien'] is double
            ? m['so_tien']
            : double.tryParse(m['so_tien'].toString()) ?? 0,
        trangThai: m['trang_thai'] ?? '',
        ngayDong: m['ngay_dong'] ?? '',
        hocKy: m['hoc_ky'] is int
            ? m['hoc_ky']
            : int.tryParse(m['hoc_ky'].toString()) ?? 1,
        namHoc: m['nam_hoc'] ?? '',
        lastUpdated: m['last_updated'] != null
            ? DateTime.tryParse(m['last_updated'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ten_khoan_thu': tenKhoanThu,
        'so_tien': soTien,
        'trang_thai': trangThai,
        'ngay_dong': ngayDong,
        'hoc_ky': hocKy,
        'nam_hoc': namHoc,
        'last_updated':
            lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  bool get daDong =>
      trangThai.toLowerCase().contains('đã') ||
      trangThai.toLowerCase().contains('da');
}

// ════════════════════════════════════════
// models/cache_meta.dart
// ════════════════════════════════════════

class CacheMeta {
  final String key;
  final String dataHash;
  final DateTime lastFetched;

  const CacheMeta({
    required this.key,
    required this.dataHash,
    required this.lastFetched,
  });

  factory CacheMeta.fromMap(Map<String, dynamic> m) => CacheMeta(
        key: m['key'],
        dataHash: m['data_hash'] ?? '',
        lastFetched: DateTime.parse(m['last_fetched']),
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'data_hash': dataHash,
        'last_fetched': lastFetched.toIso8601String(),
      };

  bool isStale(Duration ttl) => DateTime.now().difference(lastFetched) > ttl;
}

class DiemSummary {
  final double? diemKhenThuong;
  final String xepLoaiHe4;
  final String xepLoaiHe10;
  final double? tbcHocTapHe4;
  final double? tbcHocTapHe10;
  final double? tbcTichLuyHe4;
  final double? tbcTichLuyHe10;
  final int? soTinChiTichLuy;
  final int? soTinChiTichLuyMax;
  final int? soTinChiHocTap;

  const DiemSummary({
    this.diemKhenThuong,
    this.xepLoaiHe4 = '',
    this.xepLoaiHe10 = '',
    this.tbcHocTapHe4,
    this.tbcHocTapHe10,
    this.tbcTichLuyHe4,
    this.tbcTichLuyHe10,
    this.soTinChiTichLuy,
    this.soTinChiTichLuyMax,
    this.soTinChiHocTap,
  });
}
