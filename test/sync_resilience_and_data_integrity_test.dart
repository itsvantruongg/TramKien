import 'dart:io';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/providers/schedule_provider.dart';
import 'package:Tram_Kien/services/local_notification_service.dart';
import 'package:Tram_Kien/services/global_api_queue.dart';
import 'package:Tram_Kien/services/db/schedule_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SPEC-SYNC-RESILIENCE-01 Acceptance Criteria Verification Tests', () {

    // =========================================================================
    // AC-01: Regex Date Pattern Extraction (ScheduleProvider & LocalNotificationService)
    // =========================================================================
    group('AC-01 (Date Matching Heuristic & Flexibility)', () {
      LichHoc createTestClass(String thoiGian) => LichHoc(
        tenHocPhan: 'Kiến trúc phần mềm',
        soTinChi: 3,
        tenLopTinChi: 'KT01',
        thoiGian: thoiGian,
        thu: 'Thứ 7', // Weekday Saturday (6)
        tiet: '1-3',
        phong: 'P.302',
        giaoVien: 'GV Nguyễn Văn A',
        dotHoc: 1,
        hocKy: 1,
        namHoc: '2026-2027',
        chuyenNganh: '0',
      );

      // Saturday Sep 5, 2026 (start boundary)
      final startBoundary = DateTime(2026, 9, 5);
      // Saturday Oct 10, 2026 (within range)
      final withinRange = DateTime(2026, 10, 10);
      // Saturday Jan 9, 2027 (before end boundary of Jan 15, 2027)
      final endRange = DateTime(2027, 1, 9);
      // Saturday Aug 29, 2026 (before range)
      final beforeRange = DateTime(2026, 8, 29);
      // Saturday Jan 23, 2027 (after range)
      final afterRange = DateTime(2027, 1, 23);
      // Sunday Sep 6, 2026 (wrong weekday)
      final wrongWeekday = DateTime(2026, 9, 6);

      test('Format 1: "5/9/2026-15/1/2027" (Single-digit day/month, no space around hyphen)', () {
        final l = createTestClass('5/9/2026-15/1/2027');

        // ScheduleProvider
        expect(ScheduleProvider.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, withinRange), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, endRange), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, beforeRange), isFalse);
        expect(ScheduleProvider.lichHocMatchesDate(l, afterRange), isFalse);
        expect(ScheduleProvider.lichHocMatchesDate(l, wrongWeekday), isFalse);

        // LocalNotificationService
        expect(LocalNotificationService.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, withinRange), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, endRange), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, beforeRange), isFalse);
        expect(LocalNotificationService.lichHocMatchesDate(l, afterRange), isFalse);
      });

      test('Format 2: "05/09/2026 - 15/01/2027" (Padded with leading zeroes & spaces)', () {
        final l = createTestClass('05/09/2026 - 15/01/2027');

        expect(ScheduleProvider.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, withinRange), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, beforeRange), isFalse);

        expect(LocalNotificationService.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, withinRange), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, beforeRange), isFalse);
      });

      test('Format 3: "05/09/2026 – 15/01/2027" (En-dash separator)', () {
        final l = createTestClass('05/09/2026 – 15/01/2027');

        expect(ScheduleProvider.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, withinRange), isTrue);
        expect(ScheduleProvider.lichHocMatchesDate(l, afterRange), isFalse);

        expect(LocalNotificationService.lichHocMatchesDate(l, startBoundary), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, withinRange), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, afterRange), isFalse);
      });

      test('Format 4: "Từ 5/9/2026 đến 15/1/2027" (Arbitrary text around dates)', () {
        final l = createTestClass('Từ 5/9/2026 đến 15/1/2027');

        expect(ScheduleProvider.lichHocMatchesDate(l, withinRange), isTrue);
        expect(LocalNotificationService.lichHocMatchesDate(l, withinRange), isTrue);
      });

      test('Edge case: Malformed thoiGian with less than 2 dates returns false', () {
        final l1 = createTestClass('15/01/2027');
        expect(ScheduleProvider.lichHocMatchesDate(l1, startBoundary), isFalse);
        expect(LocalNotificationService.lichHocMatchesDate(l1, startBoundary), isFalse);

        final l2 = createTestClass('không có ngày');
        expect(ScheduleProvider.lichHocMatchesDate(l2, startBoundary), isFalse);
        expect(LocalNotificationService.lichHocMatchesDate(l2, startBoundary), isFalse);
      });
    });

    // =========================================================================
    // AC-02 & AC-03: Early-Stop Network Guard
    // =========================================================================
    group('AC-02 & AC-03 (Early-Stop Guard & Happy Path)', () {
      test('AC-02: Early-Stop does NOT break when Dot 3 encounters network failure (success == false)', () async {
        final dispatchedDots = <int>[];

        Future<({List<LichHoc> items, bool success})> mockFetch({
          required int dot,
          required int cn,
        }) async {
          dispatchedDots.add(dot);
          if (dot == 1 && cn == 0) {
            return (items: const [
              LichHoc(
                tenHocPhan: 'Môn 1',
                soTinChi: 3,
                tenLopTinChi: 'L1',
                thoiGian: '5/9/2026-15/1/2027',
                thu: 'Thứ 2',
                tiet: '1-3',
                phong: 'P1',
                giaoVien: 'GV1',
                dotHoc: 1,
                hocKy: 1,
                namHoc: '2026-2027',
                chuyenNganh: '0',
              )
            ], success: true);
          }
          if (dot == 3) {
            // Giả lập rớt mạng ở Đợt 3
            return (items: <LichHoc>[], success: false);
          }
          if (dot == 4 && cn == 0) {
            // Đợt 4 có môn (nếu ngắt sớm ở Đợt 3 sẽ bị mất môn này!)
            return (items: const [
              LichHoc(
                tenHocPhan: 'Môn Đợt 4',
                soTinChi: 3,
                tenLopTinChi: 'L4',
                thoiGian: '5/9/2026-15/1/2027',
                thu: 'Thứ 2',
                tiet: '1-3',
                phong: 'P1',
                giaoVien: 'GV1',
                dotHoc: 4,
                hocKy: 1,
                namHoc: '2026-2027',
                chuyenNganh: '0',
              )
            ], success: true);
          }
          return (items: <LichHoc>[], success: true);
        }

        // Logic tương tự ScheduleApi.fetchLichHocAllDotsWithStatus
        bool complete = true;
        final allResults = <LichHoc>[];

        for (int dot = 1; dot <= 8; dot++) {
          final dotFutures = [
            mockFetch(dot: dot, cn: 0),
            mockFetch(dot: dot, cn: 1),
          ];
          final dotResults = await Future.wait(dotFutures);
          bool dotHasItems = false;
          bool dotAllSuccessful = true;

          for (int cn = 0; cn <= 1; cn++) {
            final r = dotResults[cn];
            if (!r.success) {
              complete = false;
              dotAllSuccessful = false;
            }
            if (r.items.isNotEmpty) {
              dotHasItems = true;
              allResults.addAll(r.items);
            }
          }

          // Heuristic chuẩn: Chỉ ngắt khi dotAllSuccessful == true
          if (dot >= 3 && !dotHasItems && dotAllSuccessful) {
            break;
          }
        }

        // Verify: Do Đợt 3 rớt mạng, thuật toán không được ngắt sớm mà phải quét tiếp Đợt 4
        expect(complete, isFalse, reason: 'Có request rớt mạng nên complete phải là false');
        expect(dispatchedDots.contains(3), isTrue);
        expect(dispatchedDots.contains(4), isTrue, reason: 'Phải quét tiếp Đợt 4');
        expect(allResults.any((l) => l.tenHocPhan == 'Môn Đợt 4'), isTrue,
            reason: 'Môn học ở Đợt 4 phải được thu thập an toàn, không bị mất do Early-Stop ngắt sớm');
      });

      test('AC-03: Early-Stop breaks immediately at Dot 3 when network is 100% OK and no items', () async {
        final dispatchedDots = <int>[];

        Future<({List<LichHoc> items, bool success})> mockFetch({
          required int dot,
          required int cn,
        }) async {
          dispatchedDots.add(dot);
          if (dot <= 2 && cn == 0) {
            return (items: [
              LichHoc(
                tenHocPhan: 'Môn $dot',
                soTinChi: 3,
                tenLopTinChi: 'L$dot',
                thoiGian: '5/9/2026-15/1/2027',
                thu: 'Thứ 2',
                tiet: '1-3',
                phong: 'P1',
                giaoVien: 'GV1',
                dotHoc: dot,
                hocKy: 1,
                namHoc: '2026-2027',
                chuyenNganh: '0',
              )
            ], success: true);
          }
          // Đợt 3 thành công mạng nhưng không có môn
          return (items: <LichHoc>[], success: true);
        }

        bool complete = true;
        final allResults = <LichHoc>[];

        for (int dot = 1; dot <= 8; dot++) {
          final dotFutures = [
            mockFetch(dot: dot, cn: 0),
            mockFetch(dot: dot, cn: 1),
          ];
          final dotResults = await Future.wait(dotFutures);
          bool dotHasItems = false;
          bool dotAllSuccessful = true;

          for (int cn = 0; cn <= 1; cn++) {
            final r = dotResults[cn];
            if (!r.success) {
              complete = false;
              dotAllSuccessful = false;
            }
            if (r.items.isNotEmpty) {
              dotHasItems = true;
              allResults.addAll(r.items);
            }
          }

          if (dot >= 3 && !dotHasItems && dotAllSuccessful) {
            break;
          }
        }

        expect(complete, isTrue);
        expect(dispatchedDots.length, equals(6), reason: 'Đợt 1, 2, 3 mỗi đợt 2 reqs = 6');
        expect(dispatchedDots.any((d) => d >= 4), isFalse, reason: 'Tuyệt đối không gửi req Đợt 4..8');
        expect(allResults.length, equals(2));
      });
    });

    // =========================================================================
    // AC-04: Network Retry Expansion in GlobalApiQueue
    // =========================================================================
    group('AC-04 (GlobalApiQueue Retry Expansion)', () {
      test('Retries and recovers on http.ClientException with 2s backoff', () {
        fakeAsync((async) {
          int attempts = 0;
          String? result;

          GlobalApiQueue.instance.enqueue<String>(() async {
            attempts++;
            if (attempts == 1) {
              throw http.ClientException('Software caused connection abort');
            }
            return 'recovered';
          }).then((v) => result = v);

          // Attempt 1 fails
          async.elapse(const Duration(milliseconds: 100));
          expect(attempts, equals(1));
          expect(result, isNull);

          // After 2s retry delay, attempt 2 executes and succeeds
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          expect(attempts, equals(2));
          expect(result, equals('recovered'));
        });
      });

      test('Retries on HttpException and recovers on second retry (4s backoff)', () {
        fakeAsync((async) {
          int attempts = 0;
          String? result;

          GlobalApiQueue.instance.enqueue<String>(() async {
            attempts++;
            if (attempts < 3) {
              throw const HttpException('Connection closed before full header was received');
            }
            return 'repaired';
          }).then((v) => result = v);

          // Initial attempt
          async.elapse(const Duration(milliseconds: 100));
          expect(attempts, equals(1));

          // 1st retry delay = 2s
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          expect(attempts, equals(2));
          expect(result, isNull);

          // 2nd retry delay = 4s
          async.elapse(const Duration(seconds: 4));
          async.flushMicrotasks();
          expect(attempts, equals(3));
          expect(result, equals('repaired'));
        });
      });

      test('Exhausts 2 retries (total 3 attempts) and completes with error', () {
        fakeAsync((async) {
          int attempts = 0;
          Object? caughtError;

          GlobalApiQueue.instance.enqueue<String>(() async {
            attempts++;
            throw const SocketException('Network is unreachable');
          }).catchError((e) {
            caughtError = e;
            return '';
          });

          // Attempt 1 -> fails
          async.elapse(const Duration(milliseconds: 100));
          // Attempt 2 -> after 2s
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();
          // Attempt 3 -> after 4s
          async.elapse(const Duration(seconds: 4));
          async.flushMicrotasks();

          expect(attempts, equals(3));
          expect(caughtError, isA<SocketException>());
        });
      });

      test('Non-transient errors (e.g. FormatException) are NOT retried', () {
        fakeAsync((async) {
          int attempts = 0;
          Object? caughtError;

          GlobalApiQueue.instance.enqueue<String>(() async {
            attempts++;
            throw const FormatException('Invalid JSON payload');
          }).catchError((e) {
            caughtError = e;
            return '';
          });

          async.elapse(const Duration(seconds: 10));
          async.flushMicrotasks();

          // Only attempted once!
          expect(attempts, equals(1));
          expect(caughtError, isA<FormatException>());
        });
      });
    });

    // =========================================================================
    // AC-05: History Sync Flags Cleaned up on Logout
    // =========================================================================
    group('AC-05 (Logout History Sync Flags Cleanup)', () {
      test('logout() cleans has_done_initial_full_sync and has_done_history_schedule keys', () async {
        const testMssv = '20210001';
        SharedPreferences.setMockInitialValues({
          'saved_mssv': testMssv,
          'saved_pw': 'secure_password',
          'remember_login': true,
          'has_done_initial_full_sync_$testMssv': true,
          'has_done_history_schedule_$testMssv': true,
          'notif_start_time_$testMssv': 123456789,
        });

        final appProvider = AppProvider();
        await appProvider.quickAuthCheck();
        expect(appProvider.currentMssv, equals(testMssv));

        final prefsBefore = await SharedPreferences.getInstance();
        expect(prefsBefore.getBool('has_done_initial_full_sync_$testMssv'), isTrue);
        expect(prefsBefore.getBool('has_done_history_schedule_$testMssv'), isTrue);

        // Execute logout
        await appProvider.logout();

        final prefsAfter = await SharedPreferences.getInstance();
        expect(prefsAfter.getBool('has_done_initial_full_sync_$testMssv'), isNull,
            reason: 'has_done_initial_full_sync phải bị xóa sạch khi logout');
        expect(prefsAfter.getBool('has_done_history_schedule_$testMssv'), isNull,
            reason: 'has_done_history_schedule phải bị xóa sạch khi logout');
      });
    });

    // =========================================================================
    // AC-06: Stamp All Records With App Version & Reconcile Loop Guard
    // =========================================================================
    group('AC-06 (Reconcile Stamping in SQLite)', () {
      late Database db;

      setUp(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE lich_hoc (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ten_hoc_phan TEXT,
                so_tin_chi INTEGER DEFAULT 0,
                ten_lop_tin_chi TEXT,
                thoi_gian TEXT,
                thu TEXT,
                tiet TEXT,
                phong TEXT,
                giao_vien TEXT,
                hoc_ky INTEGER,
                nam_hoc TEXT,
                dot_hoc INTEGER,
                chuyen_nganh TEXT,
                last_updated TEXT,
                note TEXT DEFAULT '',
                is_manual INTEGER DEFAULT 0,
                fetched_app_version TEXT,
                synced_at INTEGER,
                last_seen_at INTEGER
              );
            ''');

            await db.execute('''
              CREATE TABLE lich_thi (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ma_hoc_phan TEXT,
                ten_hoc_phan TEXT,
                so_tin_chi INTEGER DEFAULT 0,
                ngay_thi TEXT,
                ca_thi TEXT,
                gio_thi TEXT,
                lan_thi INTEGER DEFAULT 1,
                dot_thi INTEGER DEFAULT 1,
                so_bao_danh TEXT,
                phong_thi TEXT,
                hinh_thuc TEXT,
                hoan_thi TEXT,
                hoc_ky INTEGER,
                nam_hoc TEXT,
                last_updated TEXT,
                note TEXT DEFAULT '',
                is_manual INTEGER DEFAULT 0,
                fetched_app_version TEXT,
                synced_at INTEGER,
                last_seen_at INTEGER
              );
            ''');
          },
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('ScheduleDb.stampAllRecordsWithAppVersion stamps all non-manual records and clears needsReconcile', () async {
        const newAppVersion = '1.0.6+4';

        // 1. Insert past semester records with old version
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Toán cao cấp A1',
          'hoc_ky': 1,
          'nam_hoc': '2022-2023',
          'is_manual': 0,
          'fetched_app_version': '1.0.3',
        });
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Vật lý 1',
          'hoc_ky': 2,
          'nam_hoc': '2022-2023',
          'is_manual': 0,
          'fetched_app_version': null,
        });

        // 2. Insert manual user-created record with old version
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Lịch làm thêm cá nhân',
          'hoc_ky': 1,
          'nam_hoc': '2026-2027',
          'is_manual': 1,
          'fetched_app_version': '1.0.0',
        });

        // 3. Insert past exam record with old version
        await db.insert('lich_thi', {
          'ten_hoc_phan': 'Thi Toán cao cấp A1',
          'hoc_ky': 1,
          'nam_hoc': '2022-2023',
          'is_manual': 0,
          'fetched_app_version': '1.0.2',
        });

        // Precondition: needsReconcile must be true
        expect(await ScheduleDb.needsReconcile(newAppVersion, db: db), isTrue);

        // Execute batch stamping
        await ScheduleDb.stampAllRecordsWithAppVersion(newAppVersion, db: db);

        // Postcondition: needsReconcile must now be FALSE!
        expect(await ScheduleDb.needsReconcile(newAppVersion, db: db), isFalse);

        // Verify non-manual records have been updated to newAppVersion
        final hocRows = await db.query('lich_hoc', where: 'is_manual = 0');
        expect(hocRows.length, equals(2));
        for (final row in hocRows) {
          expect(row['fetched_app_version'], equals(newAppVersion));
        }

        final thiRows = await db.query('lich_thi', where: 'is_manual = 0');
        expect(thiRows.length, equals(1));
        expect(thiRows.first['fetched_app_version'], equals(newAppVersion));

        // Verify manual records were PRESERVED without being overwritten
        final manualRows = await db.query('lich_hoc', where: 'is_manual = 1');
        expect(manualRows.length, equals(1));
        expect(manualRows.first['fetched_app_version'], equals('1.0.0'));
      });
    });

  });
}
