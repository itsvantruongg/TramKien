import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Tram_Kien/services/database_service.dart';
import 'package:Tram_Kien/services/analytics_service.dart';
import 'package:Tram_Kien/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPEC-FIREBASE-OPENSOURCE-01 Acceptance Criteria Verification Tests', () {
    setUp(() {
      AnalyticsService.resetForTesting();
    });

    tearDown(() {
      AnalyticsService.resetForTesting();
    });

    // ── AC-01: Version Bump ──────────────────────────────────────────────
    test('AC-01 (Version Bump) pubspec.yaml and DatabaseService both equal 1.1.0+5', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist');
      final content = pubspecFile.readAsStringSync();
      final match = RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(content);
      expect(match, isNotNull, reason: 'version string should be present in pubspec.yaml');
      final pubspecVersion = match!.group(1);

      expect(pubspecVersion, equals('1.1.0+5'));
      expect(DatabaseService.currentAppVersion, equals('1.1.0+5'));
      expect(DatabaseService.currentAppVersion, equals(pubspecVersion));
    });

    // ── AC-02: Security Isolation in .gitignore ──────────────────────────
    test('AC-02 (Security Isolation in .gitignore) Sensitive Firebase files are ignored', () {
      final gitignoreFile = File('.gitignore');
      expect(gitignoreFile.existsSync(), isTrue, reason: '.gitignore must exist');
      final gitignoreContent = gitignoreFile.readAsStringSync();

      expect(gitignoreContent.contains('android/app/google-services.json'), isTrue,
          reason: 'android/app/google-services.json must be in .gitignore');
      expect(gitignoreContent.contains('ios/Runner/GoogleService-Info.plist'), isTrue,
          reason: 'ios/Runner/GoogleService-Info.plist must be in .gitignore');
      expect(gitignoreContent.contains('lib/firebase_options.dart'), isTrue,
          reason: 'lib/firebase_options.dart must be in .gitignore');
    });

    // ── AC-03: Example Template ──────────────────────────────────────────
    test('AC-03 (Example Template) lib/firebase_options.dart.example exists and contains no secrets', () {
      final exampleFile = File('lib/firebase_options.dart.example');
      expect(exampleFile.existsSync(), isTrue,
          reason: 'lib/firebase_options.dart.example must exist for open-source contributors');
      final content = exampleFile.readAsStringSync();

      // Check placeholder structure
      expect(content.contains('class DefaultFirebaseOptions'), isTrue);
      expect(content.contains('YOUR-...EY'), isTrue);
      expect(content.contains('your-project-id'), isTrue);
      expect(content.contains('1:000000000000:android:0000000000000000000000'), isTrue);

      // Check real project secrets are NOT leaked in example template
      expect(content.contains('804358231949'), isFalse,
          reason: 'Real sender ID must not appear in example file');
      expect(content.contains('tramkien-c99cf'), isFalse,
          reason: 'Real project ID must not appear in example file');
    });

    // ── AC-04: Safe Initialization ───────────────────────────────────────
    test('AC-04 (Safe Initialization) AnalyticsService.initialize() executes safely in test/offline env', () async {
      // Must not throw even when running in test without native Firebase
      expect(() async => await AnalyticsService.initialize(), returnsNormally);
      expect(() async => await AnalyticsService.init(), returnsNormally);

      // Calling logging methods when uninitialized must never throw
      expect(() async => await AnalyticsService.logAppOpen(), returnsNormally);
      expect(() async => await AnalyticsService.logScreenView('schedule_view'), returnsNormally);
      expect(() async => await AnalyticsService.logViewSchedule('week'), returnsNormally);
      expect(() async => await AnalyticsService.logScheduleSync(true, 15), returnsNormally);
      expect(() async => await AnalyticsService.logOpenWidgetStudio(), returnsNormally);
      expect(() async => await AnalyticsService.logWidgetCustomized('compact', 'gradient'), returnsNormally);
      expect(() async => await AnalyticsService.logFeedbackSubmitted(), returnsNormally);
      expect(
        () async => await AnalyticsService.recordError(
          Exception('Test non-fatal error'),
          StackTrace.current,
          reason: 'AC-04 test',
        ),
        returnsNormally,
      );
    });

    // ── AC-05: Zero PII Compliance ───────────────────────────────────────
    test('AC-05 (Zero PII Compliance) Enforces whitelist and rejects all student PII keys and values', () async {
      // Whitelist validation
      expect(AnalyticsService.isWhitelistedEvent('app_open'), isTrue);
      expect(AnalyticsService.isWhitelistedEvent('view_schedule'), isTrue);
      expect(AnalyticsService.isWhitelistedEvent('sync_completed'), isTrue);
      expect(AnalyticsService.isWhitelistedEvent('open_widget_studio'), isTrue);
      expect(AnalyticsService.isWhitelistedEvent('widget_customized'), isTrue);
      expect(AnalyticsService.isWhitelistedEvent('submit_feedback'), isTrue);

      // Non-whitelisted events must be rejected
      expect(AnalyticsService.isWhitelistedEvent('user_login'), isFalse);
      expect(AnalyticsService.isWhitelistedEvent('student_credentials'), isFalse);
      expect(AnalyticsService.isWhitelistedEvent('grade_view'), isFalse);

      // PII key detection
      expect(AnalyticsService.containsPiiKey('mssv'), isTrue);
      expect(AnalyticsService.containsPiiKey('student_id'), isTrue);
      expect(AnalyticsService.containsPiiKey('password'), isTrue);
      expect(AnalyticsService.containsPiiKey('fullName'), isTrue);
      expect(AnalyticsService.containsPiiKey('phone_number'), isTrue);
      expect(AnalyticsService.containsPiiKey('email'), isTrue);
      expect(AnalyticsService.containsPiiKey('auth_token'), isTrue);
      expect(AnalyticsService.containsPiiKey('user_id'), isTrue);
      expect(AnalyticsService.containsPiiKey('diem_tong_ket'), isTrue);

      // Safe keys detection
      expect(AnalyticsService.containsPiiKey('layout_mode'), isFalse);
      expect(AnalyticsService.containsPiiKey('bg_style'), isFalse);
      expect(AnalyticsService.containsPiiKey('item_count'), isFalse);
      expect(AnalyticsService.containsPiiKey('success'), isFalse);

      // Value detection (e.g. 10-digit student ID)
      expect(AnalyticsService.containsPiiValue('2021601234'), isTrue);
      expect(AnalyticsService.containsPiiValue('compact'), isFalse);

      // Sanitization stripping PII keys & values
      final dirtyParams = <String, Object>{
        'mssv': '2021601234',
        'password': 'secret_password_123',
        'student_id': '12345678',
        'item_count': 10,
        'success': true,
        'layout_mode': 'modern',
        'suspicious_numeric_code': '2021605555',
      };

      final cleanParams = AnalyticsService.sanitizeParameters(dirtyParams);
      expect(cleanParams, isNotNull);
      expect(cleanParams!.containsKey('mssv'), isFalse);
      expect(cleanParams.containsKey('password'), isFalse);
      expect(cleanParams.containsKey('student_id'), isFalse);
      expect(cleanParams.containsKey('suspicious_numeric_code'), isFalse);
      expect(cleanParams['item_count'], equals(10));
      expect(cleanParams['success'], equals(true));
      expect(cleanParams['layout_mode'], equals('modern'));

      // Codebase audit: AnalyticsService source must not contain setUserIdentifier or track user IDs
      final serviceFile = File('lib/services/analytics_service.dart');
      final serviceSource = serviceFile.readAsStringSync();
      expect(serviceSource.contains('setUserIdentifier'), isFalse);
      expect(serviceSource.contains('setUserId'), isFalse);
    });

    test('AC-05 (Zero PII Compliance) Event logging records only whitelisted anonymous events and parameters', () async {
      await AnalyticsService.logAppOpen();
      await AnalyticsService.logScheduleSync(true, 8);
      await AnalyticsService.logWidgetCustomized('standard', 'glassmorphism');
      await AnalyticsService.logFeedbackSubmitted();
      await AnalyticsService.logOpenWidgetStudio();

      final events = AnalyticsService.loggedEventsForTesting;
      expect(events.length, equals(5));

      expect(events[0]['name'], equals('app_open'));

      expect(events[1]['name'], equals('sync_completed'));
      expect(events[1]['parameters'], equals({'success': true, 'item_count': 8}));

      expect(events[2]['name'], equals('widget_customized'));
      expect(events[2]['parameters'], equals({'layout_mode': 'standard', 'bg_style': 'glassmorphism'}));

      expect(events[3]['name'], equals('submit_feedback'));

      expect(events[4]['name'], equals('open_widget_studio'));
    });

    // ── AC-06: Automated Tests & Quality Gates ───────────────────────────
    test('AC-06 (Build Config & Gradle Plugins) Settings and App Gradle properly configure Google Services & Crashlytics', () {
      final settingsGradle = File('android/settings.gradle.kts');
      expect(settingsGradle.existsSync(), isTrue);
      final settingsContent = settingsGradle.readAsStringSync();
      expect(settingsContent.contains('com.google.gms.google-services'), isTrue);
      expect(settingsContent.contains('com.google.firebase.crashlytics'), isTrue);

      final appGradle = File('android/app/build.gradle.kts');
      expect(appGradle.existsSync(), isTrue);
      final appContent = appGradle.readAsStringSync();
      expect(appContent.contains('id("com.google.gms.google-services")'), isTrue);
      expect(appContent.contains('id("com.google.firebase.crashlytics")'), isTrue);

      final optionsFile = File('lib/firebase_options.dart');
      expect(optionsFile.existsSync(), isTrue);
      expect(DefaultFirebaseOptions.android.projectId, equals('tramkien-c99cf'));
      expect(DefaultFirebaseOptions.ios.projectId, equals('tramkien-c99cf'));
    });
  });
}
