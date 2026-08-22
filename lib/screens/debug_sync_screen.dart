// ===========================================================================
// DEBUG SYNC SCREEN — PHASE 3.5 (REVISED VERIFICATION TOOLING)
// ===========================================================================
// PURPOSE: Trigger real sync, then inspect SQLite and export complete .sql.
// RULES:
//   - NO modification to production API, parser, DB, Provider, or sync logic.
//   - Strictly debug screen + kDebugMode entry point.
//   - Full record-level verification for Schedule (parser vs SQLite).
//   - Full SQLite export (schema, indexes, ALL INSERTs).
// ===========================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/background_sync_service.dart';
import '../models/models.dart';

class DebugSyncScreen extends StatefulWidget {
  const DebugSyncScreen({super.key});

  @override
  State<DebugSyncScreen> createState() => _DebugSyncScreenState();
}

class _DebugSyncScreenState extends State<DebugSyncScreen> {
  final List<String> _log = [];
  bool _running = false;
  String? _exportPath;
  bool _useDemoSetB = false;

  final Map<String, int> _parserCounts = {};
  final Map<String, int> _dbCounts = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _useDemoSetB = p.getBool('debug_demo_set_b') ?? false);
    });
  }

  void _emit(String line) {
    debugPrint('[DebugSync] $line');
    if (mounted) {
      setState(() => _log.add(line));
    }
  }

  static const _allTables = [
    'student',
    'lich_hoc',
    'lich_thi',
    'student_grades',
    'curriculum_courses',
    'training_points',
    'registration_results',
    'payment_receipts',
    'fee_details',
    'fee_summary',
    'cache_meta',
    'session',
    'semester_summaries',
  ];

  // Helper to build deterministic composite identity key for schedule
  String _buildScheduleKey({
    required String tenHocPhan,
    required String tenLopTinChi,
    required String thu,
    required String tiet,
    required dynamic dotHoc,
    required String chuyenNganh,
  }) {
    final cleanHP = tenHocPhan.trim().toLowerCase();
    final cleanLop = tenLopTinChi.trim().toLowerCase();
    final cleanThu = thu.trim().toLowerCase();
    final cleanTiet = tiet.trim().toLowerCase();
    final cleanDot = dotHoc?.toString().trim() ?? '1';
    final cleanCN = chuyenNganh.trim().toLowerCase();
    return '$cleanHP|$cleanLop|$cleanThu|$cleanTiet|$cleanDot|$cleanCN';
  }

  Future<void> _runSync() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log.clear();
      _exportPath = null;
      _parserCounts.clear();
      _dbCounts.clear();
    });

    _emit('=== PHASE 3.5 DEBUG SYNC STARTED ===');
    _emit('Time: ${DateTime.now().toIso8601String()}');

    try {
      _emit('');
      _emit('▶ Step 1/5: Triggering real sync via AppProvider.syncAll(forceRefresh: true)...');
      final provider = context.read<AppProvider>();
      await provider.syncAll(forceRefresh: true);
      _emit('✅ syncAll() completed.');

      _emit('');
      _emit('▶ Step 2/5: Reading parser output from provider memory...');
      final parsedLichHoc = provider.scheduleProvider.lichHoc;
      final parsedLichThi = provider.scheduleProvider.lichThi;
      final parsedGrades = provider.gradeProvider.diem;

      _parserCounts['lich_hoc'] = parsedLichHoc.length;
      _parserCounts['lich_thi'] = parsedLichThi.length;
      _parserCounts['student_grades'] = parsedGrades.length;

      _emit('  lich_hoc (parser): ${parsedLichHoc.length} items');
      _emit('  lich_thi (parser): ${parsedLichThi.length} items');
      _emit('  student_grades (parser): ${parsedGrades.length} items');

      _emit('');
      _emit('▶ Step 3/5: Querying SQLite database for row counts...');
      await _queryDbCounts();

      _emit('');
      _emit('▶ Step 4/5: Detailed Record-Level Verification (Parser vs DB)...');
      await _verifyScheduleRecordLevel(parsedLichHoc);

      _emit('');
      _emit('▶ Step 5/5: Exporting full SQLite database → .sql file...');
      await _exportSql(syncNumber: 1);
    } catch (e, st) {
      _emit('❌ ERROR: $e');
      _emit('  StackTrace: ${st.toString().split('\n').take(5).join(' | ')}');
    } finally {
      if (mounted) setState(() => _running = false);
      _emit('');
      _emit('=== DEBUG SYNC FINISHED ===');
    }
  }

  Future<void> _runSync02() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log.add('');
      _log.add('=== INCREMENTAL SYNC 02 STARTED ===');
      _log.add('Time: ${DateTime.now().toIso8601String()}');
    });

    try {
      _emit('▶ Running syncAll(forceRefresh: true) again...');
      final provider = context.read<AppProvider>();
      await provider.syncAll(forceRefresh: true);
      _emit('✅ sync_02 syncAll() completed.');

      _emit('');
      _emit('▶ Querying SQLite for sync_02 counts...');
      final countsAfter = await _getDbRowCounts();

      _emit('');
      _emit('┌─ INCREMENTAL SYNC DIFF ─────────────────────');
      for (final table in _allTables) {
        final before = _dbCounts[table] ?? 0;
        final after = countsAfter[table] ?? 0;
        final diff = after - before;
        final sign = diff >= 0 ? '+' : '';
        _emit('│  $table: $before → $after ($sign$diff)');
      }
      _emit('└─────────────────────────────────────────────');

      _emit('');
      _emit('▶ Exporting sync_02.sql...');
      await _exportSql(syncNumber: 2);
    } catch (e) {
      _emit('❌ Sync 02 error: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _triggerBgTask() async {
    _emit('▶ Registering One-off Background Task (BackgroundSyncService.runOnce())...');
    try {
      await BackgroundSyncService.runOnce();
      _emit('✅ One-off task registered successfully!');
      _emit('👉 Task ID registered as: tramkien_periodic_sync_once');
      _emit('🚀 Android WorkManager will execute callbackDispatcher shortly!');
    } catch (e) {
      _emit('❌ Error registering background task: $e');
    }
  }

  // ─── Việc 3: Fault inject giả lập mất mạng giữa Future.wait ─────────────
  Future<void> _triggerFaultInject() async {
    assert(kDebugMode, '_triggerFaultInject only available in debug mode');
    _emit('');
    _emit('⚡ [FAULT-INJECT] Bắt đầu sync + inject SocketException sau 300ms...');
    _emit('   (Mục tiêu: xác nhận data cũ trong DB được giữ nguyên khi mạng mất giữa chừng)');
    try {
      await BackgroundSyncService.runOnceFaultInject(delayMs: 300);
      _emit('✅ [FAULT-INJECT] Session hoàn tất. Xem log ở trên.');
    } catch (e) {
      _emit('❌ [FAULT-INJECT] Lỗi: $e');
    }
  }

  // ─── Việc 4: Test B4 mutex — 2 lần sync đồng thời ───────────────────────
  Future<void> _triggerMutexTest() async {
    assert(kDebugMode, '_triggerMutexTest only available in debug mode');
    _emit('');
    _emit('⚡ [MUTEX-TEST] Firing 2 sync calls concurrently (<300ms gap)...');
    _emit('   (Mục tiêu: 1 lần chạy, 1 lần bị mutex chặn → thấy log "bỏ qua")');
    try {
      await BackgroundSyncService.runOnceConcurrent();
      _emit('✅ [MUTEX-TEST] Kết thúc. Xem log ở trên để xác nhận mutex hoạt động.');
    } catch (e) {
      _emit('❌ [MUTEX-TEST] Lỗi: $e');
    }
  }

  // ─── Việc 2: Đổi demo set A ↔ B (test B10) ───────────────────────────────
  Future<void> _switchDemoSet() async {
    assert(kDebugMode, '_switchDemoSet only available in debug mode');
    final prefs = await SharedPreferences.getInstance();
    final next = !_useDemoSetB;
    await prefs.setBool('debug_demo_set_b', next);
    setState(() => _useDemoSetB = next);
    final setLabel = next ? 'SET B (3 môn cũ + Hệ điều hành)' : 'SET A (baseline 4 môn)';
    _emit('🔄 Đã đổi sang $setLabel');
    _emit('▶ Đang trigger sync với bộ data mới...');
    await _triggerBgTask();
  }

  // ─── Việc 3: Giả lập version cũ (test B2 reconcile) ─────────────────────
  Future<void> _simulateOldVersion() async {
    assert(kDebugMode, '_simulateOldVersion only available in debug mode');
    try {
      final d = await DatabaseService.db;
      final oldVersion = '0.0.1';
      final updated = await d.rawUpdate(
        "UPDATE lich_hoc SET fetched_app_version = ? WHERE is_manual = 0",
        [oldVersion],
      );
      final updatedThi = await d.rawUpdate(
        "UPDATE lich_thi SET fetched_app_version = ? WHERE is_manual = 0",
        [oldVersion],
      );
      _emit('✅ Đã set fetched_app_version = "$oldVersion" cho:');
      _emit('   lich_hoc: $updated records');
      _emit('   lich_thi: $updatedThi records');
      _emit('');
      _emit('⚠️  BẮT BUỘC: Kill app hoàn toàn (không chỉ hot reload),');
      _emit('   rồi mở lại để trigger B2 reconcile trong app_provider.dart init().');
      _emit('   Reconcile KHÔNG chạy trong background sync — chỉ chạy khi app khởi động.');
    } catch (e) {
      _emit('❌ Lỗi khi giả lập version cũ: $e');
    }
  }

  Future<void> _queryDbCounts() async {
    final counts = await _getDbRowCounts();
    _dbCounts.addAll(counts);

    _emit('┌─ DATABASE ROW COUNTS ─────────────────────────');
    int totalRows = 0;
    for (final table in _allTables) {
      final count = counts[table] ?? 0;
      if (count >= 0) totalRows += count;
      _emit('│  $table: ${count >= 0 ? count : "(not created)"} rows');
    }
    _emit('│  ─────────────────────────');
    _emit('│  TOTAL: $totalRows rows across all existing tables');
    _emit('└───────────────────────────────────────────────');
  }

  Future<Map<String, int>> _getDbRowCounts() async {
    final d = await DatabaseService.db;
    final result = <String, int>{};
    for (final table in _allTables) {
      try {
        final rows = await d.rawQuery('SELECT COUNT(*) as cnt FROM $table');
        result[table] = Sqflite.firstIntValue(rows) ?? 0;
      } catch (_) {
        result[table] = -1;
      }
    }
    return result;
  }

  Future<void> _verifyScheduleRecordLevel(List<LichHoc> parserList) async {
    final d = await DatabaseService.db;

    // 1. Fetch DB records
    final dbRows = await d.query('lich_hoc');
    _emit('Parser count: ${parserList.length} | DB count: ${dbRows.length}');

    final parserMap = <String, List<LichHoc>>{};
    for (final item in parserList) {
      final key = _buildScheduleKey(
        tenHocPhan: item.tenHocPhan,
        tenLopTinChi: item.tenLopTinChi,
        thu: item.thu,
        tiet: item.tiet,
        dotHoc: item.dotHoc,
        chuyenNganh: item.chuyenNganh,
      );
      parserMap.putIfAbsent(key, () => []).add(item);
    }

    final dbMap = <String, List<Map<String, dynamic>>>{};
    for (final row in dbRows) {
      final key = _buildScheduleKey(
        tenHocPhan: row['ten_hoc_phan']?.toString() ?? '',
        tenLopTinChi: row['ten_lop_tin_chi']?.toString() ?? '',
        thu: row['thu']?.toString() ?? '',
        tiet: row['tiet']?.toString() ?? '',
        dotHoc: row['dot_hoc'] ?? 1,
        chuyenNganh: row['chuyen_nganh']?.toString() ?? '',
      );
      dbMap.putIfAbsent(key, () => []).add(row);
    }

    // Check missing, extra, duplicates
    final missingInDb = <String>[];
    final extraInDb = <String>[];
    final duplicatesInDb = <String>[];

    for (final entry in parserMap.entries) {
      if (!dbMap.containsKey(entry.key)) {
        missingInDb.add(entry.key);
      }
    }

    for (final entry in dbMap.entries) {
      if (!parserMap.containsKey(entry.key)) {
        extraInDb.add(entry.key);
      }
      if (entry.value.length > 1) {
        duplicatesInDb.add(entry.key);
      }
    }

    _emit('┌─ SCHEDULE IDENTITY & RECORD MATCHING ─────────────');
    _emit('│  Missing records in DB: ${missingInDb.length}');
    _emit('│  Extra records in DB:   ${extraInDb.length}');
    _emit('│  Duplicate keys in DB:  ${duplicatesInDb.length}');
    _emit('└───────────────────────────────────────────────────');

    if (missingInDb.isNotEmpty) {
      _emit('⚠️ MISSING IN DB:');
      for (final k in missingInDb.take(5)) {
        _emit('  - Key: $k');
      }
    }

    if (duplicatesInDb.isNotEmpty) {
      _emit('❌ DUPLICATES DETECTED IN DB:');
      for (final k in duplicatesInDb.take(5)) {
        _emit('  - Key: $k (Count: ${dbMap[k]!.length})');
      }
    }

    // Detailed verification of multi-day schedules
    _emit('');
    _emit('┌─ MULTI-DAY SCHEDULE RECORD-LEVEL VERIFICATION ─────');
    final multiDayQuery = await d.rawQuery('''
      SELECT ten_hoc_phan, ten_lop_tin_chi, hoc_ky, nam_hoc
      FROM lich_hoc
      GROUP BY ten_hoc_phan, ten_lop_tin_chi, hoc_ky, nam_hoc
      HAVING COUNT(DISTINCT thu) > 1
      LIMIT 10
    ''');

    if (multiDayQuery.isEmpty) {
      _emit('│  No multi-day courses (having distinct `thu` > 1) in current DB.');
    } else {
      for (final multi in multiDayQuery) {
        final hp = multi['ten_hoc_phan'];
        final lop = multi['ten_lop_tin_chi'];
        final hk = multi['hoc_ky'];
        final nh = multi['nam_hoc'];

        _emit('│  COURSE: $hp ($lop) [HK$hk $nh]');

        // Fetch corresponding parser records
        final pMatches = parserList.where((p) =>
            p.tenHocPhan == hp &&
            p.tenLopTinChi == lop &&
            p.hocKy == hk &&
            p.namHoc == nh);

        _emit('│    [PARSER SESSIONS]:');
        for (final item in pMatches) {
          _emit('│      - thu: "${item.thu}", tiet: "${item.tiet}", room: "${item.phong}", teacher: "${item.giaoVien}", dot_hoc: ${item.dotHoc}, chuyen_nganh: "${item.chuyenNganh}"');
        }

        // Fetch corresponding DB records
        final dMatches = dbRows.where((r) =>
            r['ten_hoc_phan'] == hp &&
            r['ten_lop_tin_chi'] == lop &&
            r['hoc_ky'] == hk &&
            r['nam_hoc'] == nh);

        _emit('│    [DATABASE SESSIONS]:');
        for (final row in dMatches) {
          _emit('│      - id: ${row['id']}, thu: "${row['thu']}", tiet: "${row['tiet']}", room: "${row['phong']}", teacher: "${row['giao_vien']}", dot_hoc: ${row['dot_hoc']}, chuyen_nganh: "${row['chuyen_nganh']}"');
        }
        _emit('│  ────────────────────────────────────────────────');
      }
    }
    _emit('└───────────────────────────────────────────────────');
  }

  Future<void> _exportSql({int syncNumber = 1}) async {
    final d = await DatabaseService.db;
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final fileName = syncNumber == 1
        ? 'flutter_sync_debug_$ts.sql'
        : 'flutter_sync_02_$ts.sql';

    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(path.join(docsDir.path, fileName));
    final sink = file.openWrite();

    sink.writeln('-- =======================================================');
    sink.writeln('-- FLUTTER SQLITE EXPORT — Phase 3.5 Full Verification');
    sink.writeln('-- Sync #$syncNumber');
    sink.writeln('-- Exported: ${DateTime.now().toIso8601String()}');
    sink.writeln('-- DB File: ${d.path}');
    sink.writeln('-- =======================================================');
    sink.writeln('');
    sink.writeln('PRAGMA foreign_keys=OFF;');
    sink.writeln('BEGIN TRANSACTION;');
    sink.writeln('');

    int totalRows = 0;

    for (final table in _allTables) {
      try {
        final schemaRows = await d.rawQuery(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='$table'");
        if (schemaRows.isNotEmpty && schemaRows.first['sql'] != null) {
          sink.writeln('-- TABLE: $table');
          sink.writeln('DROP TABLE IF EXISTS $table;');
          sink.writeln('${schemaRows.first['sql']};');
          sink.writeln('');
        }
      } catch (_) {}

      try {
        final idxRows = await d.rawQuery(
            "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='$table' AND sql IS NOT NULL");
        for (final idx in idxRows) {
          sink.writeln('${idx['sql']};');
        }
      } catch (_) {}

      try {
        final dataRows = await d.query(table);
        if (dataRows.isNotEmpty) {
          sink.writeln('');
          sink.writeln('-- DATA: $table (${dataRows.length} rows)');
          for (final row in dataRows) {
            final cols = row.keys.map(_sqlEscapeId).join(', ');
            final vals = row.values.map(_sqlEscapeVal).join(', ');
            sink.writeln('INSERT INTO $table ($cols) VALUES ($vals);');
          }
          totalRows += dataRows.length;
        } else {
          sink.writeln('-- DATA: $table (empty)');
        }
        sink.writeln('');
      } catch (e) {
        sink.writeln('-- ERROR reading $table: $e');
        sink.writeln('');
      }
    }

    sink.writeln('COMMIT;');
    sink.writeln('');
    sink.writeln('-- Total rows exported: $totalRows');
    sink.writeln('-- End of export');

    await sink.flush();
    await sink.close();

    setState(() => _exportPath = file.path);

    _emit('✅ SQL EXPORT SUCCESS');
    _emit('  Path: ${file.path}');
    _emit('  Total rows exported: $totalRows');
    _emit('  File size: ${await file.length()} bytes');
  }

  String _sqlEscapeId(String name) => '"$name"';

  String _sqlEscapeVal(dynamic val) {
    if (val == null) return 'NULL';
    if (val is int || val is double) return val.toString();
    final s = val.toString().replaceAll("'", "''");
    return "'$s'";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text(
          'Phase 3.5 — DB Verification',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_exportPath != null)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _running ? null : _runSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F6FEB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.sync, size: 14),
                        label: const Text('Sync #1 + SQL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_running || _exportPath == null) ? null : _runSync02,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.compare_arrows, size: 14),
                        label: const Text('Sync #2 (Inc)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _triggerBgTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('⚡ Trigger BG Task (BackgroundSyncService.runOnce)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                // ─── DEBUG ONLY: chỉ xuất hiện trong kDebugMode ─────────────
                if (kDebugMode) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? null : _switchDemoSet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _useDemoSetB
                            ? const Color(0xFF9B59B6)
                            : const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(_useDemoSetB ? Icons.swap_horiz : Icons.compare, size: 15),
                      label: Text(
                        _useDemoSetB
                            ? '🟣 Đang dùng SET B — Bấm về SET A (baseline)'
                            : '🟢 Đang dùng SET A — Bấm sang SET B (test B10)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? null : _simulateOldVersion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2D00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.history, size: 15),
                      label: const Text(
                        '🕰 Giả lập version cũ (test B2 reconcile)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? null : _triggerFaultInject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C2D91),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.flash_off, size: 15),
                      label: const Text(
                        '🔌 Mô phỏng mất mạng giữa sync (Fault Inject)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? null : _triggerMutexTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.layers, size: 15),
                      label: const Text(
                        '🔐 Test B4 Mutex — 2 sync đồng thời',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_exportPath != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF0D4429),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.save_alt, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportPath!,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (_running)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF161B22),
              color: Color(0xFF1F6FEB),
            ),
          Expanded(
            child: _log.isEmpty
                ? const Center(
                    child: Text(
                      'Tap "Sync #1 + Export SQL" to start\nreal pipeline verification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _log.length,
                    itemBuilder: (ctx, i) {
                      final line = _log[i];
                      Color color = Colors.white70;
                      if (line.startsWith('✅')) color = Colors.greenAccent;
                      if (line.startsWith('❌')) color = Colors.redAccent;
                      if (line.startsWith('⚠️')) color = Colors.orangeAccent;
                      if (line.startsWith('===')) color = const Color(0xFF58A6FF);
                      if (line.startsWith('▶')) color = const Color(0xFFD2A8FF);
                      if (line.startsWith('│') || line.startsWith('┌') || line.startsWith('└')) color = const Color(0xFF8B949E);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
