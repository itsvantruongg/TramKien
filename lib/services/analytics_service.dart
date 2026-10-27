import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../firebase_options.dart';

class AnalyticsService {
  AnalyticsService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;

  static FirebaseAnalytics? get analytics => _analytics;
  static FirebaseCrashlytics? get crashlytics => _crashlytics;

  @visibleForTesting
  static final List<Map<String, dynamic>> loggedEventsForTesting = [];

  static const Set<String> whitelistedEvents = {
    'app_open',
    'view_schedule',
    'sync_completed',
    'open_widget_studio',
    'widget_customized',
    'submit_feedback',
    'screen_view',
  };

  static const List<String> _piiKeys = [
    'mssv',
    'student_id',
    'student_name',
    'password',
    'pass',
    'fullname',
    'full_name',
    'first_name',
    'last_name',
    'phone',
    'email',
    'token',
    'credential',
    'user_id',
    'diem',
    'grade',
  ];

  static bool containsPiiKey(String key) {
    final lower = key.toLowerCase();
    if (lower == 'name') return true;
    return _piiKeys.any((pii) => lower.contains(pii));
  }

  static bool containsPiiValue(dynamic value) {
    if (value is String) {
      final s = value.trim();
      // Detect potential student IDs or passwords (e.g. 8-12 digits)
      if (RegExp(r'^[0-9]{8,12}$').hasMatch(s)) {
        return true;
      }
    }
    return false;
  }

  /// Initializes Firebase, Analytics, and Crashlytics safely.
  /// Never throws an unhandled exception even if configuration is missing,
  /// platform is unsupported, or running in offline/unit-test environments.
  static Future<void> initialize({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  }) async {
    if (analytics != null || crashlytics != null) {
      _analytics = analytics;
      _crashlytics = crashlytics;
      _isInitialized = true;
      return;
    }

    try {
      FirebaseOptions? options;
      try {
        options = DefaultFirebaseOptions.currentPlatform;
      } catch (e) {
        debugPrint('⚠️ [AnalyticsService] Firebase options not available: $e');
      }

      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }

      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      _isInitialized = true;

      // Automatically capture Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        try {
          if (_crashlytics != null) {
            _crashlytics!.recordFlutterFatalError(details);
          } else {
            FlutterError.presentError(details);
          }
        } catch (e) {
          debugPrint('⚠️ [AnalyticsService] FlutterError handler error: $e');
        }
      };

      // Automatically capture asynchronous platform errors
      PlatformDispatcher.instance.onError = (error, stack) {
        try {
          if (_crashlytics != null) {
            _crashlytics!.recordError(error, stack, fatal: true);
          }
        } catch (e) {
          debugPrint('⚠️ [AnalyticsService] PlatformDispatcher handler error: $e');
        }
        return true;
      };

      debugPrint('✅ [AnalyticsService] Firebase initialized successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('⚠️ [AnalyticsService] Firebase initialization skipped/failed: $e');
    }
  }

  /// Alias for initialize() per specification
  static Future<void> init() => initialize();

  static bool isWhitelistedEvent(String eventName) =>
      whitelistedEvents.contains(eventName);

  static Map<String, Object>? sanitizeParameters(
      Map<String, Object>? parameters) {
    if (parameters == null) return null;
    final sanitized = <String, Object>{};
    for (final entry in parameters.entries) {
      if (containsPiiKey(entry.key)) {
        debugPrint(
            '⚠️ [AnalyticsService] Zero PII violation: rejected key "${entry.key}"');
        continue;
      }
      if (containsPiiValue(entry.value)) {
        debugPrint(
            '⚠️ [AnalyticsService] Zero PII violation: rejected value for key "${entry.key}"');
        continue;
      }
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  /// Logs whitelisted anonymous event with strict Zero PII enforcement
  static Future<void> _logWhitelistedEvent(
    String eventName, [
    Map<String, Object>? parameters,
  ]) async {
    if (!isWhitelistedEvent(eventName)) {
      debugPrint('⚠️ [AnalyticsService] Rejected non-whitelisted event: $eventName');
      return;
    }

    final sanitizedParams = sanitizeParameters(parameters);

    loggedEventsForTesting.add({
      'name': eventName,
      'parameters': sanitizedParams,
    });

    try {
      if (_analytics != null) {
        await _analytics!.logEvent(
          name: eventName,
          parameters: sanitizedParams,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsService] Failed to log event $eventName: $e');
    }
  }

  /// Log app opening
  static Future<void> logAppOpen() async {
    loggedEventsForTesting.add({
      'name': 'app_open',
      'parameters': null,
    });
    try {
      if (_analytics != null) {
        await _analytics!.logAppOpen();
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsService] logAppOpen error: $e');
    }
  }

  /// Log screen view (anonymous screen name only)
  static Future<void> logScreenView(String screenName) async {
    if (containsPiiKey(screenName) || containsPiiValue(screenName)) {
      debugPrint('⚠️ [AnalyticsService] Zero PII violation: screenName contains PII');
      return;
    }
    try {
      if (_analytics != null) {
        await _analytics!.logScreenView(screenName: screenName);
      }
      if (screenName == 'schedule' || screenName == 'view_schedule') {
        await logViewSchedule(screenName);
      } else {
        await _logWhitelistedEvent('screen_view', {'screen_name': screenName});
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsService] logScreenView error: $e');
    }
  }

  /// Log viewing schedule
  static Future<void> logViewSchedule([String? viewMode]) async {
    final params = viewMode != null ? <String, Object>{'view_mode': viewMode} : null;
    await _logWhitelistedEvent('view_schedule', params);
  }

  /// Log schedule synchronization completion
  static Future<void> logScheduleSync(bool success, int itemCount) async {
    await _logWhitelistedEvent('sync_completed', {
      'success': success,
      'item_count': itemCount,
    });
  }

  /// Log opening widget studio
  static Future<void> logOpenWidgetStudio() async {
    await _logWhitelistedEvent('open_widget_studio');
  }

  /// Log widget customization event
  static Future<void> logWidgetCustomized(String layoutMode, String bgStyle) async {
    await _logWhitelistedEvent('widget_customized', {
      'layout_mode': layoutMode,
      'bg_style': bgStyle,
    });
  }

  /// Log user feedback submission
  static Future<void> logFeedbackSubmitted() async {
    await _logWhitelistedEvent('submit_feedback');
  }

  /// Safe error logging with Crashlytics
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    try {
      if (_crashlytics != null) {
        await _crashlytics!.recordError(
          exception,
          stack,
          reason: reason,
          information: information,
          fatal: fatal,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsService] recordError failed: $e');
    }
  }

  /// Reset internal state for test environment isolation
  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
    _analytics = null;
    _crashlytics = null;
    loggedEventsForTesting.clear();
  }
}
