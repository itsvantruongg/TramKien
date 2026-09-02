import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Tram_Kien/services/background_sync_service.dart';
import 'package:Tram_Kien/services/database_service.dart';
import 'package:Tram_Kien/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Background Sync & Data Integrity Real SQLite Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE lich_hoc (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten_hoc_phan TEXT NOT NULL,
              so_tin_chi INTEGER DEFAULT 0,
              ten_lop_tin_chi TEXT DEFAULT '',
              thoi_gian TEXT DEFAULT '',
              thu TEXT DEFAULT '',
              tiet TEXT DEFAULT '',
              phong TEXT DEFAULT '',
              giao_vien TEXT DEFAULT '',
              hoc_ky INTEGER NOT NULL,
              nam_hoc TEXT NOT NULL,
              dot_hoc INTEGER NOT NULL DEFAULT 1,
              chuyen_nganh TEXT DEFAULT '',
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
              ma_hoc_phan TEXT DEFAULT '',
              ten_hoc_phan TEXT NOT NULL,
              so_tin_chi INTEGER DEFAULT 0,
              ngay_thi TEXT DEFAULT '',
              ca_thi TEXT DEFAULT '',
              gio_thi TEXT DEFAULT '',
              lan_thi INTEGER DEFAULT 1,
              dot_thi INTEGER DEFAULT 1,
              so_bao_danh TEXT DEFAULT '',
              phong_thi TEXT DEFAULT '',
              hinh_thuc TEXT DEFAULT '',
              hoan_thi TEXT DEFAULT '',
              hoc_ky INTEGER NOT NULL,
              nam_hoc TEXT NOT NULL,
              last_updated TEXT DEFAULT '',
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

    test(
        'B1 Real Production Call - ScheduleDb.saveLichHoc diff-delete & scope isolation',
        () async {
      // Seed Scope A (hocKy: 1, namHoc: 2024-2025, dotHoc: 1): 4 API + 1 Manual
      for (int i = 1; i <= 4; i++) {
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Môn cũ Scope A $i',
          'hoc_ky': 1,
          'nam_hoc': '2024-2025',
          'dot_hoc': 1,
          'is_manual': 0,
        });
      }
      await db.insert('lich_hoc', {
        'ten_hoc_phan': 'Lịch cá nhân Scope A',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'dot_hoc': 1,
        'is_manual': 1,
      });

      // Seed Scope B (hocKy: 2, namHoc: 2024-2025, dotHoc: 1): 2 API
      for (int i = 1; i <= 2; i++) {
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Môn Scope B $i',
          'hoc_ky': 2,
          'nam_hoc': '2024-2025',
          'dot_hoc': 1,
          'is_manual': 0,
        });
      }

      // 3 New LichHoc objects for Scope A
      final newItems = List.generate(
        3,
        (i) => LichHoc(
          tenHocPhan: 'Môn mới Scope A ${i + 1}',
          soTinChi: 3,
          tenLopTinChi: 'Lop 0$i',
          thoiGian: '01/09-30/12',
          thu: 'Thứ ${i + 2}',
          tiet: '1-3',
          phong: 'A$i',
          giaoVien: 'GV A',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      );

      // CALL PRODUCTION METHOD DIRECTLY with injected db
      await ScheduleDb.saveLichHoc(newItems, db: db, softDeleteAfter: true);

      // Verify Scope A API records replaced (4 old deleted -> 3 new inserted)
      final scopeAApi =
          await db.query('lich_hoc', where: 'hoc_ky = 1 AND is_manual = 0');
      expect(scopeAApi.length, equals(3));
      expect(scopeAApi.first['ten_hoc_phan'], equals('Môn mới Scope A 1'));
      expect(scopeAApi.first['fetched_app_version'],
          equals(DatabaseService.currentAppVersion));

      // Verify Scope A Manual record preserved
      final scopeAManual =
          await db.query('lich_hoc', where: 'hoc_ky = 1 AND is_manual = 1');
      expect(scopeAManual.length, equals(1));
      expect(
          scopeAManual.first['ten_hoc_phan'], equals('Lịch cá nhân Scope A'));

      // Verify Scope B records untouched (Scope isolation)
      final scopeBApi = await db.query('lich_hoc', where: 'hoc_ky = 2');
      expect(scopeBApi.length, equals(2));
    });

    test(
        'B1 Real Production Call - saveLichHoc rollback on mid-transaction failure',
        () async {
      // 1. Seed Scope A (hocKy: 1, namHoc: 2024-2025, dotHoc: 1): 4 API + 1 Manual
      for (int i = 1; i <= 4; i++) {
        await db.insert('lich_hoc', {
          'ten_hoc_phan': 'Môn API cũ $i',
          'hoc_ky': 1,
          'nam_hoc': '2024-2025',
          'dot_hoc': 1,
          'is_manual': 0,
        });
      }
      await db.insert('lich_hoc', {
        'ten_hoc_phan': 'Lịch cá nhân thủ công',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'dot_hoc': 1,
        'is_manual': 1,
      });

      final countBefore = (await db.rawQuery('SELECT COUNT(*) FROM lich_hoc'))
          .first
          .values
          .first as int;
      expect(countBefore, equals(5));

      // 2. Set an SQLite BEFORE INSERT trigger to trigger a mid-insert failure
      await db.execute('''
        CREATE TRIGGER fail_on_invalid_item BEFORE INSERT ON lich_hoc
        WHEN NEW.ten_hoc_phan LIKE 'FAIL_%'
        BEGIN
          SELECT RAISE(FAIL, 'Simulated SQLite Transaction Mid-Insert Failure');
        END;
      ''');

      // 3. Create list where 1st item succeeds, 2nd item triggers SQLite RAISE(FAIL)
      final newItems = [
        const LichHoc(
          tenHocPhan: 'Môn hợp lệ 1',
          soTinChi: 3,
          tenLopTinChi: 'L01',
          thoiGian: '01/09',
          thu: 'Thứ 2',
          tiet: '1-3',
          phong: 'A1',
          giaoVien: 'GV1',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
        const LichHoc(
          tenHocPhan: 'FAIL_Môn_Gây_Lỗi',
          soTinChi: 3,
          tenLopTinChi: 'L02',
          thoiGian: '01/09',
          thu: 'Thứ 4',
          tiet: '4-6',
          phong: 'A2',
          giaoVien: 'GV2',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      // 4. CALL PRODUCTION METHOD ScheduleDb.saveLichHoc DIRECTLY
      bool exceptionThrown = false;
      try {
        await ScheduleDb.saveLichHoc(newItems, db: db);
      } catch (e) {
        exceptionThrown = true;
        expect(e.toString(),
            contains('Simulated SQLite Transaction Mid-Insert Failure'));
      }
      expect(exceptionThrown, isTrue,
          reason: 'ScheduleDb.saveLichHoc must throw on SQLite failure');

      // 5. Verify SQLite atomic rollback:
      // - 4 API records restored (DELETE rolled back)
      final scopeApiCount = (await db.rawQuery(
              'SELECT COUNT(*) FROM lich_hoc WHERE hoc_ky = 1 AND dot_hoc = 1 AND is_manual = 0'))
          .first
          .values
          .first as int;
      expect(scopeApiCount, equals(4),
          reason: 'DELETE of 4 API records must be completely rolled back');

      // - 1 Manual record preserved
      final manualCount = (await db.rawQuery(
              'SELECT COUNT(*) FROM lich_hoc WHERE hoc_ky = 1 AND dot_hoc = 1 AND is_manual = 1'))
          .first
          .values
          .first as int;
      expect(manualCount, equals(1),
          reason: 'Manual record must remain untouched');

      // - Total count is still 5 (partial insert rolled back)
      final countAfter = (await db.rawQuery('SELECT COUNT(*) FROM lich_hoc'))
          .first
          .values
          .first as int;
      expect(countAfter, equals(5),
          reason: 'Total records in DB must be exactly 5 (full rollback)');

      final partialInsert = await db.query('lich_hoc',
          where: 'ten_hoc_phan = ?', whereArgs: ['Môn hợp lệ 1']);
      expect(partialInsert.isEmpty, isTrue,
          reason: 'Item inserted before failure must be rolled back');
    });

    test(
        'B7 Real Production Call - ScheduleDb.saveLichThi diff-delete & scope isolation',
        () async {
      // Seed Scope A (hocKy: 1, namHoc: 2024-2025): 4 API + 1 Manual
      for (int i = 1; i <= 4; i++) {
        await db.insert('lich_thi', {
          'ten_hoc_phan': 'Thi cũ $i',
          'hoc_ky': 1,
          'nam_hoc': '2024-2025',
          'is_manual': 0,
        });
      }
      await db.insert('lich_thi', {
        'ten_hoc_phan': 'Thi tự chọn',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'is_manual': 1,
      });

      // Seed Scope B (hocKy: 2, namHoc: 2024-2025): 2 API
      for (int i = 1; i <= 2; i++) {
        await db.insert('lich_thi', {
          'ten_hoc_phan': 'Thi Scope B $i',
          'hoc_ky': 2,
          'nam_hoc': '2024-2025',
          'is_manual': 0,
        });
      }

      // 3 New LichThi objects for Scope A
      final newItems = List.generate(
        3,
        (i) => LichThi(
          maMonHoc: 'THI0$i',
          tenMonHoc: 'Môn thi mới ${i + 1}',
          soTinChi: 3,
          ngayThi: '15/01/2025',
          caThi: 'Ca $i',
          gioBatDau: '07:30',
          phong: 'P10$i',
          hocKy: 1,
          namHoc: '2024-2025',
        ),
      );

      // CALL PRODUCTION METHOD DIRECTLY with injected db
      await ScheduleDb.saveLichThi(newItems, db: db, softDeleteAfter: true);

      // Verify Scope A: 4 old API deleted, 3 new inserted, 1 manual preserved
      final scopeAApi =
          await db.query('lich_thi', where: 'hoc_ky = 1 AND is_manual = 0');
      expect(scopeAApi.length, equals(3));
      expect(scopeAApi.first['fetched_app_version'],
          equals(DatabaseService.currentAppVersion));

      final scopeAManual =
          await db.query('lich_thi', where: 'hoc_ky = 1 AND is_manual = 1');
      expect(scopeAManual.length, equals(1));
      expect(scopeAManual.first['ten_hoc_phan'], equals('Thi tự chọn'));

      // Verify Scope B untouched
      final scopeBApi = await db.query('lich_thi', where: 'hoc_ky = 2');
      expect(scopeBApi.length, equals(2));
    });

    test('B2 Real Production Call - ScheduleDb.needsReconcile logic validation',
        () async {
      const currentVer = '1.0.5+3';

      // Case 1: Empty DB -> returns false
      expect(await ScheduleDb.needsReconcile(currentVer, db: db), isFalse);

      // Case 2: Only manual records with old version -> returns false (manual records do not trigger reconcile)
      await db.insert('lich_hoc', {
        'ten_hoc_phan': 'Môn tự tạo',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'is_manual': 1,
        'fetched_app_version': '1.0.0',
      });
      expect(await ScheduleDb.needsReconcile(currentVer, db: db), isFalse);

      // Case 3: API record with current version -> returns false
      await db.insert('lich_hoc', {
        'ten_hoc_phan': 'Môn API chuẩn',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'is_manual': 0,
        'fetched_app_version': '1.0.5+3',
      });
      expect(await ScheduleDb.needsReconcile(currentVer, db: db), isFalse);

      // Case 4: API record with NULL fetched_app_version -> returns true
      await db.insert('lich_hoc', {
        'ten_hoc_phan': 'Môn API thiếu version',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'is_manual': 0,
        'fetched_app_version': null,
      });
      expect(await ScheduleDb.needsReconcile(currentVer, db: db), isTrue);

      // Clean up & test Case 5: API record with older version -> returns true
      await db.delete('lich_hoc', where: 'fetched_app_version IS NULL');
      await db.insert('lich_thi', {
        'ten_hoc_phan': 'Môn thi version cũ',
        'hoc_ky': 1,
        'nam_hoc': '2024-2025',
        'is_manual': 0,
        'fetched_app_version': '1.0.4',
      });
      expect(await ScheduleDb.needsReconcile(currentVer, db: db), isTrue);
    });

    test(
        'B10 Real Production Call - ScheduleDiffCalculator detects additions and removals',
        () {
      const prevLichHoc = [
        LichHoc(
          tenHocPhan: 'Toán A',
          soTinChi: 3,
          tenLopTinChi: 'L01',
          thoiGian: '01/09',
          thu: 'Thứ 2',
          tiet: '1-3',
          phong: 'A1',
          giaoVien: 'GV1',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
        LichHoc(
          tenHocPhan: 'Lý B',
          soTinChi: 3,
          tenLopTinChi: 'L02',
          thoiGian: '01/09',
          thu: 'Thứ 4',
          tiet: '4-6',
          phong: 'A2',
          giaoVien: 'GV2',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      const nextLichHoc = [
        LichHoc(
          tenHocPhan: 'Lý B',
          soTinChi: 3,
          tenLopTinChi: 'L02',
          thoiGian: '01/09',
          thu: 'Thứ 4',
          tiet: '4-6',
          phong: 'A2',
          giaoVien: 'GV2',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
        LichHoc(
          tenHocPhan: 'Hóa C',
          soTinChi: 3,
          tenLopTinChi: 'L03',
          thoiGian: '01/09',
          thu: 'Thứ 6',
          tiet: '1-3',
          phong: 'A3',
          giaoVien: 'GV3',
          hocKy: 1,
          namHoc: '2024-2025',
          dotHoc: 1,
          chuyenNganh: 'CNTT',
        ),
      ];

      // CALL PRODUCTION ScheduleDiffCalculator
      final diff =
          ScheduleDiffCalculator.computeLichHocDiff(prevLichHoc, nextLichHoc);

      expect(diff.added.length, equals(1));
      expect(diff.added.first, contains('Hóa C'));
      expect(diff.removed.length, equals(1));
      expect(diff.removed.first, contains('Toán A'));

      const prevLichThi = [
        LichThi(
            maMonHoc: 'THI01',
            tenMonHoc: 'Toán A',
            ngayThi: '10/01',
            caThi: 'Ca 1',
            hocKy: 1,
            namHoc: '2024-2025'),
      ];
      const nextLichThi = [
        LichThi(
            maMonHoc: 'THI02',
            tenMonHoc: 'Lý B',
            ngayThi: '12/01',
            caThi: 'Ca 2',
            hocKy: 1,
            namHoc: '2024-2025'),
      ];

      final diffThi =
          ScheduleDiffCalculator.computeLichThiDiff(prevLichThi, nextLichThi);
      expect(diffThi.added.length, equals(1));
      expect(diffThi.added.first, contains('Lý B'));
      expect(diffThi.removed.length, equals(1));
      expect(diffThi.removed.first, contains('Toán A'));
    });

    test(
        'B4 Real Production Call - SyncMutex acquireLock prevents concurrent sync executions',
        () async {
      const testMssv = 'TEST_MSSV_B4_HARDENED';

      await SyncMutex.releaseLock(testMssv);

      final lock1 = await SyncMutex.acquireLock(testMssv,
          timeout: const Duration(seconds: 10));
      expect(lock1, isTrue, reason: 'First lock acquisition must succeed');

      final lock2 = await SyncMutex.acquireLock(testMssv,
          timeout: const Duration(seconds: 10));
      expect(lock2, isFalse,
          reason: 'Second lock acquisition during active lease must fail');

      await SyncMutex.releaseLock(testMssv);

      final lock3 = await SyncMutex.acquireLock(testMssv,
          timeout: const Duration(seconds: 10));
      expect(lock3, isTrue,
          reason: 'Lock acquisition after release must succeed');

      await SyncMutex.releaseLock(testMssv);
    });

    test(
        'Version Integrity - DatabaseService.currentAppVersion matches pubspec.yaml',
        () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();
      final match =
          RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(content);
      expect(match, isNotNull);
      final pubspecVersion = match!.group(1);

      expect(DatabaseService.currentAppVersion, equals(pubspecVersion));
    });
  });
}
