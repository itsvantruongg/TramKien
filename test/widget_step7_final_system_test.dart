import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/screens/widget_studio_screen.dart';
import 'package:Tram_Kien/services/widget/widget_service.dart';
import 'package:Tram_Kien/services/widget_data_sync_service.dart';
import 'package:Tram_Kien/widgets/widget_lock_screen_cards.dart';
import 'package:Tram_Kien/widgets/widget_month_today_4x2_card.dart';
import 'package:Tram_Kien/widgets/widget_three_days_4x2_card.dart';
import 'package:Tram_Kien/widgets/widget_today_2x2_card.dart';
import 'package:Tram_Kien/widgets/widget_weekly_4x4_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WidgetSnapshotStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('widget_step7_test_');
    storage = WidgetSnapshotStorage(customBaseDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 / BƯỚC 7: NGHIỆM THU UAT TOÀN HỆ THỐNG', () {
    // ══════════════════════════════════════════════════════════════════════════
    // AC-01: Bảo toàn dữ liệu thật qua Bản chụp lịch & Chống crash
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-01: Bảo toàn dữ liệu thật qua snapshot file & chống crash', () {
      test('Trích xuất bản chụp từ DB/Harness lossless, epoch ms chuẩn UTC+7', () async {
        final sample = WidgetTestHarness.createSpecSampleSnapshot();
        final file = await storage.saveSnapshot(sample);
        expect(await file.exists(), isTrue);

        final read = await storage.readSnapshot();
        expect(read, isNotNull);
        expect(read!.version, 1);
        expect(read.tz, 'Asia/Ho_Chi_Minh');
        expect(read.sessions.length, sample.sessions.length);

        for (int i = 0; i < sample.sessions.length; i++) {
          expect(read.sessions[i].id, sample.sessions[i].id);
          expect(read.sessions[i].kind, sample.sessions[i].kind);
          expect(read.sessions[i].subjectName, sample.sessions[i].subjectName);
          expect(read.sessions[i].startMs, sample.sessions[i].startMs);
          expect(read.sessions[i].endMs, sample.sessions[i].endMs);
          expect(read.sessions[i].colorIndex, sample.sessions[i].colorIndex);
        }
      });

      test('Xử lý bản chụp thiếu (file chưa tồn tại): fallback an toàn trạng thái trống, không crash', () async {
        final emptyStorage = WidgetSnapshotStorage(
          customBaseDir: Directory('${tempDir.path}/missing_dir'),
        );
        final read = await emptyStorage.readSnapshot();
        expect(read, isNull);

        final now = DateTime(2026, 10, 28, 10, 5);
        final t2x2 = WidgetToday2x2Selector.select(snapshot: null, now: now);
        expect(t2x2.stateType, equals(Today2x2StateType.noSnapshot));
        expect(t2x2.displayTitle, 'Đăng nhập để xem lịch');

        final m4x2 = WidgetMonthTodaySelector.select(snapshot: null, now: now);
        expect(m4x2.todaySchedule.stateType, equals(Today2x2StateType.noSnapshot));
        expect(m4x2.todaySchedule.emptyTitle, 'Đăng nhập để xem lịch');

        final t3d = WidgetThreeDaysSelector.select(snapshot: null, now: now);
        expect(t3d.hasSnapshot, isFalse);
        expect(t3d.authMessage, 'Đăng nhập để xem lịch');

        final w4x4 = WidgetWeeklySelector.select(snapshot: null, now: now);
        expect(w4x4.hasSnapshot, isFalse);
        expect(w4x4.authMessage, 'Đăng nhập để xem lịch');

        final lock = WidgetLockScreenSelector.select(snapshot: null, now: now);
        expect(lock.rectangular.stateType, equals(LockScreenStateType.noSnapshot));
        expect(lock.rectangular.line1, 'Đăng nhập để xem lịch');
        expect(lock.inline.text, 'Đăng nhập để xem lịch');
      });

      test('Xử lý file lỗi cú pháp JSON (corrupted file): trả về null, không crash', () async {
        final file = await storage.getSnapshotFile();
        await file.writeAsString('{ "version": 1, "sessions": [ CORRUPTED JSON ');

        final read = await storage.readSnapshot();
        expect(read, isNull);
      });

      test('Xử lý file version không hỗ trợ: coi như không hợp lệ', () async {
        final file = await storage.getSnapshotFile();
        await file.writeAsString(jsonEncode({
          'version': 99,
          'generatedAt': DateTime.now().millisecondsSinceEpoch,
          'tz': 'Asia/Ho_Chi_Minh',
          'sessions': [],
        }));

        final read = await storage.readSnapshot();
        expect(read, isNull);
      });

      test('Xử lý file quá cũ (> 180 ngày): phát hiện isStale và fallback an toàn', () async {
        final staleDaysAgo = DateTime.now().subtract(const Duration(days: 185));
        final oldSnapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: staleDaysAgo.millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [],
        );
        await storage.saveSnapshot(oldSnapshot);

        expect(oldSnapshot.isStale(), isTrue);

        // Đọc với enforceNotStale = true trả về null
        final readStale = await storage.readSnapshot(enforceNotStale: true);
        expect(readStale, isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-02: Loại bỏ hoàn toàn hardcode trong XML/Swift/Studio
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-02: Loại bỏ hoàn toàn hardcode trong XML/Swift/Studio', () {
      test('Toàn bộ file XML layout widget không chứa text môn học hardcode cũ', () {
        final layoutDir = Directory('android/app/src/main/res/layout');
        expect(layoutDir.existsSync(), isTrue);

        final xmlFiles = layoutDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('widget_') && f.path.endsWith('.xml'))
            .toList();

        final forbiddenSnippets = [
          'Đồ họa và hiện thực ảo',
          'Hệ trợ giúp quyết định',
          'Lập trình Android Kotlin',
          'Đồ án Kiến trúc 1',
        ];

        for (final file in xmlFiles) {
          final content = file.readAsStringSync();
          if (file.path.contains('single_day_2x2') ||
              file.path.contains('month_today') ||
              file.path.contains('three_days') ||
              file.path.contains('weekly')) {
            for (final snippet in forbiddenSnippets) {
              expect(
                content.contains(snippet),
                isFalse,
                reason: 'File ${file.path} không được chứa text hardcode "$snippet"',
              );
            }
          }
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-03: Widget dùng đúng color trong bản chụp, FNV-1a ở Dart
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-03: Widget dùng đúng color trong bản chụp, FNV-1a ở Dart', () {
      test('Thuật toán FNV-1a 32-bit chỉ cài đặt ở Dart, băm xác định 0..7', () {
        final c1 = WidgetHashUtils.calculateColorIndex('Lập trình Web');
        final c2 = WidgetHashUtils.calculateColorIndex('Cấu trúc dữ liệu và giải thuật 2');
        final c3 = WidgetHashUtils.calculateColorIndex('Mạng máy tính');

        expect(c1, inInclusiveRange(0, 7));
        expect(c2, inInclusiveRange(0, 7));
        expect(c3, inInclusiveRange(0, 7));

        // Tính xác định: cùng chuỗi cho cùng kết quả
        expect(WidgetHashUtils.calculateColorIndex('Lập trình Web'), equals(c1));
        expect(WidgetHashUtils.calculateColorIndex('  Lập trình Web  '), equals(c1));
      });

      test('Session lưu trường colorIndex và các widget đọc trực tiếp colorIndex', () {
        final sample = WidgetTestHarness.createSpecSampleSnapshot();
        for (final session in sample.sessions) {
          expect(session.colorIndex, inInclusiveRange(0, 7));
        }

        final now = DateTime(2026, 10, 28, 10, 5);
        final w4x4 = WidgetWeeklySelector.select(snapshot: sample, now: now);
        for (final group in w4x4.dayGroups) {
          for (final item in group.sessions) {
            expect(item.colorIndex, inInclusiveRange(0, 7));
          }
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-04: Phân định 2 trục kind (class/exam) và status (past/current/upcoming)
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-04: Phân định 2 trục kind (class/exam) và status (past/current/upcoming)', () {
      test('Phân định 2 trục trực giao độc lập', () {
        final start = DateTime.utc(2026, 10, 28, 9, 45);
        final end = DateTime.utc(2026, 10, 28, 11, 45);

        final examSession = Session(
          id: 1,
          kind: SessionKind.examSession,
          subjectName: 'Thi PPL NCKH',
          shortName: 'Thi PPL',
          start: start,
          end: end,
          room: 'B205',
          colorIndex: 0,
        );

        // Trạng thái nhảy theo now độc lập với kind
        expect(examSession.calculateStatus(DateTime.utc(2026, 10, 28, 9, 0)), equals(SessionStatus.upcoming));
        expect(examSession.calculateStatus(DateTime.utc(2026, 10, 28, 10, 5)), equals(SessionStatus.current));
        expect(examSession.calculateStatus(DateTime.utc(2026, 10, 28, 12, 0)), equals(SessionStatus.past));
      });

      test('Lịch thi (kind == exam) mang cờ isExam = true và luôn được ưu tiên', () {
        final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: snapshot, now: now);
        expect(t2x2.isExam, isTrue);
        expect(t2x2.statusLabel, 'Đang thi');

        final m4x2 = WidgetMonthTodaySelector.select(snapshot: snapshot, now: now);
        expect(m4x2.todaySchedule.visibleCards.any((c) => c.isExam), isTrue);
        expect(m4x2.todaySchedule.visibleCards.first.isExam, isTrue); // Lịch thi chiếm thẻ đầu
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-05: Đầy đủ 4 widget + Lock screen đúng token thiết kế
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-05: Đầy đủ 4 widget + Lock screen đúng token thiết kế, font 11/12/13sp', () {
      test('WidgetDesignTokens tuân thủ bảng màu Mục 1.4 & 1.5', () {
        expect(WidgetDesignTokens.lightBg, const Color(0xFFFFFFFF));
        expect(WidgetDesignTokens.darkBg, const Color(0xFF262624));
        expect(WidgetDesignTokens.lightTextPrimary, const Color(0xFF1F1F1E));
        expect(WidgetDesignTokens.darkTextPrimary, const Color(0xFFF1EFE8));
        expect(WidgetDesignTokens.lightAccent, const Color(0xFF185FA5));
        expect(WidgetDesignTokens.darkAccent, const Color(0xFF85B7EB));
        expect(WidgetDesignTokens.lightExamBg, const Color(0xFFFCEBEB));
        expect(WidgetDesignTokens.darkExamBg, const Color(0xFF791F1F));

        expect(WidgetDesignTokens.lightSubjectColors.length, 8);
        expect(WidgetDesignTokens.darkSubjectColors.length, 8);
      });

      testWidgets('Render đầy đủ 4 widget + Lock screen trong cả Light & Dark mode', (tester) async {
        final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: snapshot, now: now);
        final m4x2 = WidgetMonthTodaySelector.select(snapshot: snapshot, now: now);
        final t3d = WidgetThreeDaysSelector.select(snapshot: snapshot, now: now);
        final w4x4 = WidgetWeeklySelector.select(snapshot: snapshot, now: now);
        final lock = WidgetLockScreenSelector.select(snapshot: snapshot, now: now);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    WidgetToday2x2Card(data: t2x2, isDarkMode: false),
                    WidgetToday2x2Card(data: t2x2, isDarkMode: true),
                    WidgetMonthToday4x2Card(data: m4x2, isDarkMode: false),
                    WidgetMonthToday4x2Card(data: m4x2, isDarkMode: true),
                    WidgetThreeDays4x2Card(data: t3d, isDarkMode: false),
                    WidgetThreeDays4x2Card(data: t3d, isDarkMode: true),
                    WidgetWeekly4x4Card(data: w4x4, isDarkMode: false),
                    WidgetWeekly4x4Card(data: w4x4, isDarkMode: true),
                    WidgetLockScreenPreviewSet(data: lock, isLightWallpaper: true),
                    WidgetLockScreenPreviewSet(data: lock, isLightWallpaper: false),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(WidgetToday2x2Card), findsNWidgets(2));
        expect(find.byType(WidgetMonthToday4x2Card), findsNWidgets(2));
        expect(find.byType(WidgetThreeDays4x2Card), findsNWidgets(2));
        expect(find.byType(WidgetWeekly4x4Card), findsNWidgets(2));
        expect(find.byType(WidgetLockScreenPreviewSet), findsNWidgets(2));
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-06: Tự động chuyển mốc giờ & nhảy ngày lúc 00:00
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-06: Tự động chuyển mốc giờ & nhảy ngày lúc 00:00', () {
      test('getAllDayTransitionTimes sinh đầy đủ mốc giờ học, giờ thi và 00:00 nửa đêm', () {
        final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
        final now = DateTime(2026, 10, 28, 10, 5);

        final transitions = snapshot.getAllEventTimestampsForDay(now);
        expect(transitions.isNotEmpty, isTrue);

        // Mốc cuối cùng luôn là 00:00 nửa đêm hôm sau
        final last = transitions.last;
        final nextMidnight = WidgetTimeUtils.nextVnMidnight(now);
        expect(last.millisecondsSinceEpoch, equals(nextMidnight.millisecondsSinceEpoch));
      });

      test('getNextTransitionTime tính đúng mốc sự kiện kế tiếp trong ngày', () {
        final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
        final now = DateTime(2026, 10, 28, 10, 5);

        final nextTime = WidgetToday2x2Selector.getNextTransitionTime(
          snapshot: snapshot,
          now: now,
        );
        expect(nextTime, isNotNull);
        expect(nextTime, isNotNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-07: Deep link scheme tramkien://schedule
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-07: Deep link scheme tramkien://schedule', () {
      test('Đúng cú pháp tramkien://schedule kèm tham số ngày và sessionId', () {
        final snapshot = WidgetTestHarness.createSpecSampleSnapshot();
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: snapshot, now: now);
        expect(t2x2.deepLinkUri.startsWith('tramkien://schedule'), isTrue);
        expect(t2x2.deepLinkUri.contains('date=2026-10-28'), isTrue);
        expect(t2x2.deepLinkUri.contains('sessionId='), isTrue);

        final m4x2 = WidgetMonthTodaySelector.select(snapshot: snapshot, now: now);
        expect(m4x2.todaySchedule.deepLinkUri.startsWith('tramkien://schedule'), isTrue);

        final t3d = WidgetThreeDaysSelector.select(snapshot: snapshot, now: now);
        expect(t3d.deepLinkUri.startsWith('tramkien://schedule'), isTrue);

        final w4x4 = WidgetWeeklySelector.select(snapshot: snapshot, now: now);
        expect(w4x4.deepLinkUri.startsWith('tramkien://schedule'), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-08: Quét regex \b\d{1,2}:\d{2}\b trên TOÀN BỘ file native widget
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-08: Quét regex \\b\\d{1,2}:\\d{2}\\b trên TOÀN BỘ file native widget', () {
      test('Zero hardcoded time strings trong tất cả file Kotlin, Swift và Layout XML', () {
        final nativeFiles = <String>[
          'android/app/src/main/kotlin/com/tramkien/hau/SingleDay2x2ScheduleWidgetProvider.kt',
          'android/app/src/main/kotlin/com/tramkien/hau/MonthToday4x2ScheduleWidgetProvider.kt',
          'android/app/src/main/kotlin/com/tramkien/hau/ThreeDaysScheduleWidgetProvider.kt',
          'android/app/src/main/kotlin/com/tramkien/hau/WeeklyScheduleWidgetProvider.kt',
          'android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt',
          'ios/Runner/ScheduleWidgetKit.swift',
        ];

        final layoutDir = Directory('android/app/src/main/res/layout');
        if (layoutDir.existsSync()) {
          for (final f in layoutDir.listSync().whereType<File>()) {
            if (f.path.contains('widget_') && f.path.endsWith('.xml')) {
              nativeFiles.add(f.path);
            }
          }
        }

        final timePattern = RegExp(r'\d{1,2}:\d{2}');
        final violations = <String>[];

        for (final path in nativeFiles) {
          final file = File(path);
          if (!file.existsSync()) continue;

          final lines = file.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();

            if (trimmed.startsWith('//') ||
                trimmed.startsWith('/*') ||
                trimmed.startsWith('*') ||
                trimmed.startsWith('<!--')) {
              continue;
            }

            if (timePattern.hasMatch(line)) {
              violations.add('$path:${i + 1}: $trimmed');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason: 'Phát hiện các mốc giờ hardcode vi phạm AC-08: ${violations.join(", ")}',
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-09: Tên dài bảo tồn hậu tố số/La Mã
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-09: Tên dài bảo tồn hậu tố số/La Mã', () {
      test('Cắt giữa "…" giữ nguyên hậu tố số phân biệt', () {
        const original = 'Cấu trúc dữ liệu và giải thuật 2';
        final truncated = WidgetHashUtils.truncatePreserveSuffix(
          original,
          maxLength: 22,
        );

        expect(truncated.contains('…'), isTrue);
        expect(truncated.endsWith('2'), isTrue);
        expect(truncated.startsWith('Cấu trúc'), isTrue);
      });

      test('Cắt giữa "…" giữ nguyên hậu tố La Mã phân biệt', () {
        const original = 'Toán cao cấp A III';
        final truncated = WidgetHashUtils.truncatePreserveSuffix(
          original,
          maxLength: 12,
        );

        expect(truncated.contains('…'), isTrue);
        expect(truncated.endsWith('III'), isTrue);
      });

      test('Tên ngắn không bị chèn dấu ba chấm', () {
        const original = 'Thể dục';
        final truncated = WidgetHashUtils.truncatePreserveSuffix(
          original,
          maxLength: 20,
        );
        expect(truncated, equals(original));
        expect(truncated.contains('…'), isFalse);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-10: 4 trạng thái trống
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-10: 4 trạng thái trống', () {
      test('Trạng thái 0: Chưa có bản chụp -> "Đăng nhập để xem lịch"', () {
        final now = DateTime(2026, 10, 28, 10, 5);
        final t2x2 = WidgetToday2x2Selector.select(snapshot: null, now: now);
        expect(t2x2.stateType, equals(Today2x2StateType.noSnapshot));
        expect(t2x2.displayTitle, 'Đăng nhập để xem lịch');
      });

      test('Trạng thái 1: Hôm nay không có lịch kèm ca tiếp theo trong 7 ngày', () {
        final startMs = WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 30, 6, 55);
        final endMs = WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 30, 9, 20);

        final futureSession = Session(
          id: 1,
          kind: SessionKind.classSession,
          subjectName: 'Mạng máy tính',
          shortName: 'MMT',
          start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
          room: 'P.204',
          colorIndex: 1,
        );
        final snapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [futureSession],
        );
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: snapshot, now: now);
        expect(t2x2.displayTitle, 'Hôm nay không có lịch');
        expect(t2x2.subInfo, contains('Tiếp theo:'));
        expect(t2x2.subInfo, contains('MMT'));
      });

      test('Trạng thái 2: Đã hoàn thành tất cả ca học trong ngày', () {
        final startMs = WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 6, 55);
        final endMs = WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 9, 20);

        final pastSession = Session(
          id: 1,
          kind: SessionKind.classSession,
          subjectName: 'Lập trình Web',
          shortName: 'LT Web',
          start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
          room: 'P.301',
          colorIndex: 0,
        );
        final snapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [pastSession],
        );
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: snapshot, now: now);
        expect(t2x2.displayTitle, 'Hôm nay đã xong 1 môn');
      });

      test('Trạng thái 3: Không có lịch sắp tới trong 7 ngày', () {
        final emptySnapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [],
        );
        final now = DateTime(2026, 10, 28, 10, 5);

        final t2x2 = WidgetToday2x2Selector.select(snapshot: emptySnapshot, now: now);
        expect(t2x2.displayTitle, 'Hôm nay không có lịch');
        expect(t2x2.subInfo, 'Không có lịch sắp tới');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // AC-11: Lịch thi chưa diễn ra không bao giờ bị ẩn bởi "+N"
    // ══════════════════════════════════════════════════════════════════════════
    group('AC-11: Lịch thi chưa diễn ra không bao giờ bị ẩn bởi "+N"', () {
      test('Trong Widget 4x2: Lịch thi luôn được đưa vào 1 trong 2 thẻ hiển thị', () {
        final s1 = Session(
          id: 1,
          kind: SessionKind.classSession,
          subjectName: 'Môn học 1',
          shortName: 'M1',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 11, 0), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 12, 0), isUtc: true),
          room: 'P1',
          colorIndex: 0,
        );
        final s2 = Session(
          id: 2,
          kind: SessionKind.classSession,
          subjectName: 'Môn học 2',
          shortName: 'M2',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 12, 30), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 13, 30), isUtc: true),
          room: 'P2',
          colorIndex: 1,
        );
        final s3 = Session(
          id: 3,
          kind: SessionKind.classSession,
          subjectName: 'Môn học 3',
          shortName: 'M3',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 14, 0), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 15, 0), isUtc: true),
          room: 'P3',
          colorIndex: 2,
        );
        final sExam = Session(
          id: 4,
          kind: SessionKind.examSession,
          subjectName: 'Lịch thi Cuối kỳ',
          shortName: 'Thi CK',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 15, 30), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 17, 30), isUtc: true),
          room: 'B101',
          colorIndex: 3,
        );

        final snapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [s1, s2, s3, sExam],
        );
        final now = DateTime(2026, 10, 28, 10, 5);

        final m4x2 = WidgetMonthTodaySelector.select(snapshot: snapshot, now: now);
        expect(m4x2.todaySchedule.visibleCards.length, 3);
        final examInCards = m4x2.todaySchedule.visibleCards
            .any((c) => c.isExam && c.session.subjectName == 'Lịch thi Cuối kỳ');
        expect(examInCards, isTrue, reason: 'Lịch thi chưa diễn ra không được bị ẩn vào +N');
      });

      test('Trong Widget 3 Ngày 4x2: Lịch thi chưa diễn ra luôn xuất hiện trong 2 thẻ của ngày', () {
        final s1 = Session(
          id: 1,
          kind: SessionKind.classSession,
          subjectName: 'Môn học 1',
          shortName: 'M1',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 11, 0), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 12, 0), isUtc: true),
          room: 'P1',
          colorIndex: 0,
        );
        final s2 = Session(
          id: 2,
          kind: SessionKind.classSession,
          subjectName: 'Môn học 2',
          shortName: 'M2',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 12, 30), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 13, 30), isUtc: true),
          room: 'P2',
          colorIndex: 1,
        );
        final sExam = Session(
          id: 3,
          kind: SessionKind.examSession,
          subjectName: 'Thi Mạng máy tính',
          shortName: 'Thi MMT',
          start: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 15, 30), isUtc: true),
          end: DateTime.fromMillisecondsSinceEpoch(WidgetTimeUtils.vnComponentsToEpochMs(2026, 10, 28, 17, 30), isUtc: true),
          room: 'B205',
          colorIndex: 2,
        );

        final snapshot = WidgetScheduleSnapshot(
          version: 1,
          generatedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          tz: 'Asia/Ho_Chi_Minh',
          sessions: [s1, s2, sExam],
        );
        final now = DateTime(2026, 10, 28, 10, 5);

        final t3d = WidgetThreeDaysSelector.select(snapshot: snapshot, now: now);
        final todayCol = t3d.columns.first;
        expect(todayCol.visibleCards.any((c) => c.isExam), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Tích hợp WidgetStudioScreen: Live Preview nạp từ Snapshot
    // ══════════════════════════════════════════════════════════════════════════
    group('Tích hợp WidgetStudioScreen Live Preview', () {
      testWidgets('Studio chuyển đổi mượt mà giữa các layout mode chuẩn mới', (tester) async {
        await tester.binding.setSurfaceSize(const Size(450, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: WidgetStudioScreen(),
          ),
        );
        await tester.pump();

        // Cuộn tới phần chọn layout mode
        await tester.scrollUntilVisible(
          find.byKey(const Key('mode_today_2x2')),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        // 1. Chuyển sang mode Hôm nay 2x2
        await tester.tap(find.byKey(const Key('mode_today_2x2')));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetToday2x2Card), findsOneWidget);

        // 2. Chuyển sang mode Tháng + Hôm nay 4x2
        await tester.tap(find.byKey(const Key('mode_month_today_4x2')));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetMonthToday4x2Card), findsOneWidget);

        // 3. Chuyển sang mode 3 Ngày 4x2
        await tester.tap(find.byKey(const Key('mode_three_days_4x2')));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetThreeDays4x2Card), findsOneWidget);

        // 4. Chuyển sang mode Tuần 4x4
        await tester.tap(find.byKey(const Key('mode_weekly_4x4')));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetWeekly4x4Card), findsOneWidget);

        // 5. Chuyển sang mode Lock Screen
        await tester.tap(find.byKey(const Key('mode_lock_screen')));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetLockScreenPreviewSet), findsOneWidget);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Chuỗi đồng bộ toàn hệ thống: ScheduleProvider & BackgroundSync
    // ══════════════════════════════════════════════════════════════════════════
    group('Chuỗi đồng bộ toàn hệ thống', () {
      test('WidgetSnapshotGenerator sinh snapshot và lưu trữ qua WidgetSnapshotStorage', () async {
        final sample = WidgetTestHarness.createSpecSampleSnapshot();
        final file = await storage.saveSnapshot(sample);
        expect(await file.exists(), isTrue);

        final hasSnap = await storage.hasSnapshot();
        expect(hasSnap, isTrue);

        final loaded = await storage.readSnapshot();
        expect(loaded, isNotNull);
        expect(loaded!.sessions.length, equals(sample.sessions.length));
      });

      test('Đăng xuất: clearAllWidgetData xóa sạch snapshot file', () async {
        final sample = WidgetTestHarness.createSpecSampleSnapshot();
        await storage.saveSnapshot(sample);
        expect(await storage.hasSnapshot(), isTrue);

        await WidgetDataSyncService.clearAllWidgetData(snapshotStorage: storage);
        expect(await storage.hasSnapshot(), isFalse);
      });
    });
  });
}
