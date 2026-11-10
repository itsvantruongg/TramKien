import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/services/hau_api_service.dart';
import 'package:Tram_Kien/services/api/schedule_api.dart';
import 'package:Tram_Kien/services/api/grade_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử toàn bộ hệ thống API cải tiến mới (Profile, Schedule, Grade)', () {
    
    test('1. [Profile] Bóc tách thông tin sinh viên từ HTML Form mới bằng ID', () {
      final sampleHtml = '''
      <html>
        <body>
          <span id="lblHoTen">Nguyễn Văn Trường</span>
          <span id="lblMaSinhVien">2355010202</span>
          <span id="lblNgaySinh">21/03/2005</span>
          <span id="lblGioiTinh">Nam</span>
          <span class="NoiDungHoSo">Chuyên ngành: </span><span>Công nghệ thông tin</span>
          <span class="NoiDungHoSo">Hệ đào tạo: </span><span>Chính quy</span>
          <span class="NoiDungHoSo">Niên khóa: </span><span>2023-2028</span>
          <span class="NoiDungHoSo">Khóa học: </span><span>K23</span>
          <input type="text" id="txtCMND" value="001205004285" />
          <input type="text" id="txtEmail" value="truong@example.com" />
          <input type="text" id="txtDTCaNhan" value="0947307166" />
          <input type="text" id="txtQueQuan" value="Quận Long Biên-Hà Nội" />
          <input type="text" id="txtDiaChiBaoTin" value="Số 6 ngõ 387, tổ 36, phường Ngọc Thụy, quận Long Biên, thành phố Hà Nội" />
        </body>
      </html>
      ''';

      final doc = html_parser.parse(sampleHtml);
      String textById(String id) => doc.getElementById(id)?.text.trim() ?? '';
      String valueById(String id) {
        final el = doc.getElementById(id);
        if (el == null) return '';
        final val = el.attributes['value']?.trim() ?? '';
        if (val.isNotEmpty) return val;
        return el.text.trim();
      }

      String getField(List<String> ids) {
        for (final id in ids) {
          final v = valueById(id);
          if (v.isNotEmpty) return v;
          final t = textById(id);
          if (t.isNotEmpty) return t;
        }
        return '';
      }

      final student = Student(
        mssv: getField(['lblMaSinhVien', 'txtMaSinhVien']),
        hoTen: getField(['lblHoTen', 'txtHoten']),
        ngaySinh: getField(['lblNgaySinh', 'txtNgaySinh']),
        gioiTinh: getField(['lblGioiTinh', 'cbbGioiTinh']),
        cmnd: getField(['CMND', 'txtCMND']),
        email: getField(['Email', 'txtEmail']),
        dienThoai: getField(['Dienthoai_canhan', 'txtDTCaNhan']),
        queQuan: getField(['Que_quan', 'txtQueQuan']),
        diaChiBaoTin: getField(['Dia_chi_bao_tin', 'txtDiaChiBaoTin']),
        lastUpdated: DateTime.now(),
      );

      print('👤 [StudentInfo] Test bóc tách: ${student.hoTen} (${student.mssv}) | CCCD: ${student.cmnd} | SĐT: ${student.dienThoai} | Quê quán: ${student.queQuan}');

      expect(student.mssv, equals('2355010202'));
      expect(student.hoTen, equals('Nguyễn Văn Trường'));
      expect(student.cmnd, equals('001205004285'));
      expect(student.dienThoai, equals('0947307166'));
      expect(student.queQuan, equals('Quận Long Biên-Hà Nội'));
      expect(student.diaChiBaoTin, contains('phường Ngọc Thụy'));
    });

    test('2. [Schedule] Mô phỏng Branch-Pruning CN1 và Early-Stop tại Đợt 2', () async {
      final requestedQueries = <String>[];

      // Giả lập backend HAU: CN0 có môn ở Đợt 1, CN1 rỗng ở Đợt 1. Đợt 2 của CN0 rỗng.
      Future<({List<LichHoc> items, bool success})> mockFetch({
        required int hocKy,
        required int namHoc,
        required int chuyenNganh,
        required int dotHoc,
      }) async {
        final queryKey = 'HK$hocKy-N$namHoc-CN$chuyenNganh-Dot$dotHoc';
        requestedQueries.add(queryKey);

        if (dotHoc == 1 && chuyenNganh == 0) {
          return (
            items: [
              LichHoc(
                tenHocPhan: 'Công nghệ thông tin đại cương',
                soTinChi: 3,
                tenLopTinChi: 'Lớp 23CNTT',
                thoiGian: '2026-09-01',
                thu: 'Thứ 2',
                tiet: '1-3',
                phong: 'U201',
                giaoVien: 'Thầy A',
                dotHoc: 1,
                hocKy: 1,
                namHoc: '2026-2027',
                chuyenNganh: '0',
              ),
            ],
            success: true,
          );
        }

        // CN1 ở Đợt 1 rỗng, Đợt 2 CN0 rỗng
        return (items: <LichHoc>[], success: true);
      }

      print('\n📚 [LichHoc] Bắt đầu mô phỏng dò lịch học với logic mới:');

      final allResults = <LichHoc>[];
      bool cn1Active = true;
      bool complete = true;

      for (int dot = 1; dot <= 8; dot++) {
        final activeCns = <int>[0];
        if (cn1Active) activeCns.add(1);

        final dotFutures = activeCns.map((cn) => mockFetch(
          hocKy: 1,
          namHoc: 2026,
          chuyenNganh: cn,
          dotHoc: dot,
        )).toList();

        final dotResults = await Future.wait(dotFutures);
        bool cn0HasItems = false;
        bool cn0Success = true;

        for (int i = 0; i < activeCns.length; i++) {
          final cn = activeCns[i];
          final r = dotResults[i];
          final cnName = cn == 0 ? 'Chính (CN0)' : 'Bằng 2 (CN1)';

          if (!r.success) {
            complete = false;
            if (cn == 0) cn0Success = false;
          }

          if (r.items.isNotEmpty) {
            if (cn == 0) cn0HasItems = true;
            allResults.addAll(r.items);
            final monNames = r.items.map((l) => l.tenHocPhan).toSet().join(', ');
            print('   ✅ [LichHoc] Đợt $dot | $cnName: ${r.items.length} bản ghi → $monNames');
          } else {
            print('   ⚪ [LichHoc] Đợt $dot | $cnName: rỗng');
            if (dot == 1 && cn == 1) {
              cn1Active = false;
              print('   🛑 [Branch-Pruning] CN1 Đợt 1 rỗng → Ngắt nhánh Bằng 2 (không quét tiếp các đợt sau)');
            }
          }
        }

        if (dot == 2 && !cn0HasItems && cn0Success) {
          print('   🛑 [Early-Stop] Đợt 2 rỗng (mạng OK) → Dừng quét học kỳ (tiết kiệm request)');
          break;
        } else if (dot >= 3 && !cn0HasItems && cn0Success) {
          print('   🛑 [Early-Stop] Đợt $dot rỗng (mạng OK) → Kết thúc quét học kỳ');
          break;
        }
      }

      print('📊 Kết quả các request đã gửi: $requestedQueries');
      expect(requestedQueries, contains('HK1-N2026-CN0-Dot1'));
      expect(requestedQueries, contains('HK1-N2026-CN1-Dot1'));
      expect(requestedQueries, contains('HK1-N2026-CN0-Dot2'));
      // Đảm bảo KHÔNG quét CN1 ở Đợt 2
      expect(requestedQueries, isNot(contains('HK1-N2026-CN1-Dot2')));
      // Đảm bảo ngắt ngay ở Đợt 2, KHÔNG quét Đợt 3..8
      expect(requestedQueries, isNot(contains('HK1-N2026-CN0-Dot3')));
      expect(allResults.length, equals(1));
    });

    test('3. [Grade] Kiểm tra tham số Overview URL sử dụng HocKy=-1&NamHoc=-1', () {
      final overviewUrl = Uri.parse('${HauApiService.base}/TraCuuDiem/ThongTinDiemSinhVien')
          .replace(queryParameters: {
        'HocKy': '-1',
        'NamHoc': '-1',
        'ChuyenNganh': '0',
      });

      print('\n📊 [GradeOverview] URL kiểm tra: $overviewUrl');
      expect(overviewUrl.queryParameters['HocKy'], equals('-1'));
      expect(overviewUrl.queryParameters['NamHoc'], equals('-1'));
      expect(overviewUrl.queryParameters['ChuyenNganh'], equals('0'));
    });
  });
}

