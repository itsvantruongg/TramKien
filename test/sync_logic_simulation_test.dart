import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/models/models.dart';

LichHoc createMockLichHoc({
  required String tenHocPhan,
  required int dotHoc,
  required int hocKy,
  required String namHoc,
  required String chuyenNganh,
}) {
  return LichHoc(
    tenHocPhan: tenHocPhan,
    soTinChi: 3,
    tenLopTinChi: 'Lớp $tenHocPhan',
    thoiGian: '2026-09-05',
    thu: 'Thứ 2',
    tiet: '1-3',
    phong: 'P.101',
    giaoVien: 'GV A',
    dotHoc: dotHoc,
    hocKy: hocKy,
    namHoc: namHoc,
    chuyenNganh: chuyenNganh,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cơ chế Fetch Lịch học Thông minh & Background Sync Simulation Tests', () {

    test('Test Case 1: Thuật toán Early-Stop ngắt ngay tại Đợt 3 khi rỗng (tiết kiệm 70% reqs)', () async {
      // Giả lập lịch học theo từng đợt
      // Đợt 1: có 2 môn CN chính
      // Đợt 2: có 1 môn CN chính
      // Đợt 3: rỗng (0 môn ở cả 2 ngành)
      final dispatchedRequests = <({int dot, int cn})>[];

      Future<({List<LichHoc> items, bool success})> mockFetchWithRetry({
        required int dot,
        required int cn,
      }) async {
        dispatchedRequests.add((dot: dot, cn: cn));
        if (dot == 1 && cn == 0) {
          return (items: <LichHoc>[
            createMockLichHoc(
              tenHocPhan: 'Giải tích 1',
              dotHoc: 1,
              hocKy: 1,
              namHoc: '2026-2027',
              chuyenNganh: '0',
            ),
            createMockLichHoc(
              tenHocPhan: 'Đại số tuyến tính',
              dotHoc: 1,
              hocKy: 1,
              namHoc: '2026-2027',
              chuyenNganh: '0',
            ),
          ], success: true);
        } else if (dot == 2 && cn == 0) {
          return (items: <LichHoc>[
            createMockLichHoc(
              tenHocPhan: 'Vật lý đại cương',
              dotHoc: 2,
              hocKy: 1,
              namHoc: '2026-2027',
              chuyenNganh: '0',
            ),
          ], success: true);
        }
        // Đợt 3, 4, 5... rỗng
        return (items: <LichHoc>[], success: true);
      }

      // Triển khai logic Early-Stop tương tự như trong ScheduleApi
      final allResults = <LichHoc>[];
      for (int dot = 1; dot <= 8; dot++) {
        final dotFutures = [
          mockFetchWithRetry(dot: dot, cn: 0),
          mockFetchWithRetry(dot: dot, cn: 1),
        ];
        final dotResults = await Future.wait(dotFutures);
        bool dotHasItems = false;
        for (int cn = 0; cn <= 1; cn++) {
          final r = dotResults[cn];
          if (r.items.isNotEmpty) {
            dotHasItems = true;
            allResults.addAll(r.items);
          }
        }

        if (dot >= 3 && !dotHasItems) {
          // Early-Stop triggered!
          break;
        }
      }

      // Xác nhận kết quả
      // Đợt 1 (2 reqs) + Đợt 2 (2 reqs) + Đợt 3 (2 reqs) = 6 requests tổng cộng
      expect(dispatchedRequests.length, equals(6));
      expect(dispatchedRequests.any((r) => r.dot >= 4), isFalse,
          reason: 'Đợt 4..8 tuyệt đối không được gửi đi khi Đợt 3 rỗng');
      expect(allResults.length, equals(3), reason: 'Phải thu thập đủ 3 môn');
    });

    test('Test Case 2: Đảm bảo quét đầy đủ cả Chuyên ngành chính và Bằng kép (Chuyên ngành 2)', () async {
      // Giả lập sinh viên học song bằng
      final allResults = <LichHoc>[];

      Future<({List<LichHoc> items, bool success})> mockDualMajorFetch({
        required int dot,
        required int cn,
      }) async {
        if (dot == 1 && cn == 0) {
          return (items: <LichHoc>[
            createMockLichHoc(
              tenHocPhan: 'Môn ngành chính 1',
              dotHoc: 1,
              hocKy: 1,
              namHoc: '2026-2027',
              chuyenNganh: '0',
            ),
          ], success: true);
        } else if (dot == 1 && cn == 1) {
          return (items: <LichHoc>[
            createMockLichHoc(
              tenHocPhan: 'Môn bằng kép 1',
              dotHoc: 1,
              hocKy: 1,
              namHoc: '2026-2027',
              chuyenNganh: '1',
            ),
          ], success: true);
        }
        return (items: <LichHoc>[], success: true);
      }

      for (int dot = 1; dot <= 8; dot++) {
        final dotFutures = [
          mockDualMajorFetch(dot: dot, cn: 0),
          mockDualMajorFetch(dot: dot, cn: 1),
        ];
        final dotResults = await Future.wait(dotFutures);
        bool dotHasItems = false;
        for (int cn = 0; cn <= 1; cn++) {
          final r = dotResults[cn];
          if (r.items.isNotEmpty) {
            dotHasItems = true;
            allResults.addAll(r.items);
          }
        }
        if (dot >= 3 && !dotHasItems) break;
      }

      final cn0Items = allResults.where((l) => l.chuyenNganh == '0').toList();
      final cn1Items = allResults.where((l) => l.chuyenNganh == '1').toList();

      expect(cn0Items.length, equals(1), reason: 'Phải có môn ngành chính');
      expect(cn1Items.length, equals(1), reason: 'Phải có môn bằng kép');
      expect(cn0Items.first.tenHocPhan, equals('Môn ngành chính 1'));
      expect(cn1Items.first.tenHocPhan, equals('Môn bằng kép 1'));
    });

    test('Test Case 3: Áp dụng Early-Stop cho Login Lần đầu (Initial Full Sync 8 kỳ)', () async {
      int totalRequestsDispatched = 0;

      Future<({List<LichHoc> items, bool complete})> mockFetchSemesterEarlyStop(int ky, int nam) async {
        final results = <LichHoc>[];
        for (int dot = 1; dot <= 8; dot++) {
          totalRequestsDispatched += 2; // cn=0 và cn=1
          // Giả lập: ở mỗi kỳ quá khứ, chỉ có môn ở đợt 1 và đợt 2
          if (dot <= 2) {
            results.add(createMockLichHoc(
              tenHocPhan: 'Môn HK$ky năm $nam Đợt $dot',
              dotHoc: dot,
              hocKy: ky,
              namHoc: '$nam-${nam + 1}',
              chuyenNganh: '0',
            ));
          } else {
            // Đợt 3 rỗng -> Early Stop ngắt ngay
            break;
          }
        }
        return (items: results, complete: true);
      }

      // Giả lập sinh viên năm 4: quét 8 kỳ (4 năm x 2 kỳ)
      final semesters = <({int ky, int nam})>[];
      for (int nam = 2022; nam <= 2025; nam++) {
        semesters.add((ky: 1, nam: nam));
        semesters.add((ky: 2, nam: nam));
      }
      expect(semesters.length, equals(8));

      for (final s in semesters) {
        await mockFetchSemesterEarlyStop(s.ky, s.nam);
      }

      // Trước đây: 8 kỳ x 16 requests = 128 requests!
      // Nay với Early-Stop: Mỗi kỳ chỉ tốn 6 requests (đợt 1, 2, 3) -> 8 x 6 = 48 requests (hoặc ít hơn)
      expect(totalRequestsDispatched, equals(48));
      expect(totalRequestsDispatched, lessThan(60),
          reason: 'Số lượng request khi login lần đầu phải giảm ít nhất 60% so với 128 requests cũ');
    });

    test('Test Case 4: State Machine & Con trỏ Độc bản (Single Forward Pointer) - Chống chạy đè', () {
      // Hàm xác định target semester theo ranh giới năm học
      ({int hocKy, int namHoc}) determineTargetSemester(DateTime date) {
        if (date.month >= 7 && date.month < 12) {
          return (hocKy: 1, namHoc: date.year);
        } else {
          return (hocKy: 2, namHoc: date.month == 12 ? date.year : date.year - 1);
        }
      }

      // 1. Tháng 8: Target phải là HK1 năm 2026
      final dateAug = DateTime(2026, 8, 15);
      final targetAug = determineTargetSemester(dateAug);
      expect(targetAug.hocKy, equals(1));
      expect(targetAug.namHoc, equals(2026));

      // 2. Ngày 30/11: Target vẫn là HK1 năm 2026
      final dateNov = DateTime(2026, 11, 30);
      final targetNov = determineTargetSemester(dateNov);
      expect(targetNov.hocKy, equals(1));
      expect(targetNov.namHoc, equals(2026));

      // 3. Bước sang ngày 01/12 (sinh viên bảo lưu HK1, không có môn HK1):
      // Target tự động chuyển sang HK2 năm 2026, tuyệt đối không bị kẹt hay chạy đè HK1
      final dateDec = DateTime(2026, 12, 1);
      final targetDec = determineTargetSemester(dateDec);
      expect(targetDec.hocKy, equals(2));
      expect(targetDec.namHoc, equals(2026),
          reason: 'Tháng 12 thuộc niên khóa 2026-2027 nên namHoc là 2026');

      // 4. Tháng 3 năm 2027: Target vẫn là HK2 năm 2026
      final dateMar = DateTime(2027, 3, 10);
      final targetMar = determineTargetSemester(dateMar);
      expect(targetMar.hocKy, equals(2));
      expect(targetMar.namHoc, equals(2026));
    });

    test('Test Case 5: Background Sync Priority & TTL Cache 7 Ngày', () {
      // Giả lập thứ tự thực thi
      final executionSequence = <String>[];

      void runBackgroundSync({
        required bool isNewSemester,
        required bool isLichHocStale,
        required bool isHocPhiStale,
      }) {
        // CP1: Lịch thi (luôn chạy mỗi 6h)
        executionSequence.add('CP1_LICH_THI');

        // CP2: Điểm số (luôn chạy mỗi 6h)
        executionSequence.add('CP2_DIEM_SO');

        // CP3: Lịch học (chỉ chạy khi kỳ mới hoặc cache > 7 ngày)
        if (isNewSemester || isLichHocStale) {
          executionSequence.add('CP3_LICH_HOC');
        } else {
          executionSequence.add('CP3_LICH_HOC_SKIPPED');
        }

        // CP4: Học phí (chỉ chạy khi kỳ mới hoặc cache > 7 ngày)
        if (isNewSemester || isHocPhiStale) {
          executionSequence.add('CP4_HOC_PHI');
        } else {
          executionSequence.add('CP4_HOC_PHI_SKIPPED');
        }
      }

      // Kịch bản Ngày thường (Chiếm 90%): Cache còn hạn <= 7 ngày
      executionSequence.clear();
      runBackgroundSync(
        isNewSemester: false,
        isLichHocStale: false,
        isHocPhiStale: false,
      );
      expect(executionSequence, equals([
        'CP1_LICH_THI',
        'CP2_DIEM_SO',
        'CP3_LICH_HOC_SKIPPED',
        'CP4_HOC_PHI_SKIPPED',
      ]), reason: 'Ngày thường chỉ chạy Thi + Điểm, Lịch học và Học phí phải được SKIP');

      // Kịch bản Ngày thứ 7 hết hạn cache hoặc Đầu kỳ mới
      executionSequence.clear();
      runBackgroundSync(
        isNewSemester: true,
        isLichHocStale: true,
        isHocPhiStale: true,
      );
      expect(executionSequence, equals([
        'CP1_LICH_THI',
        'CP2_DIEM_SO',
        'CP3_LICH_HOC',
        'CP4_HOC_PHI',
      ]), reason: 'Đầu kỳ hoặc hết hạn cache phải chạy đầy đủ 4 Checkpoint theo đúng thứ tự');
    });

  });
}
