import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class AnalyticsService {
  AnalyticsService._();

  static bool _initialized = false;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  static Future<void> setAccountType(String mssv) async {
    if (!_isSupportedPlatform) return;
    await initialize();

    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'account_type',
        value: mssv.toLowerCase() == 'admin' ? 'demo' : 'student',
      );
    } catch (e) {
      debugPrint('Firebase setAccountType failed: $e');
    }
  }

  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isSupportedPlatform) return;
    await initialize();

    try {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('Firebase logScreenView failed: $e');
    }
  }
}
