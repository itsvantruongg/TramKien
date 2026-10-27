import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'database_service.dart';

class AppInfoService {
  static String _version = '';
  static String _buildNumber = '';
  static String _cachedFullVersion = DatabaseService.currentAppVersion;
  static String? _manualMockVersion;

  /// Single Source of Truth for App Version in frontend UI
  static String get currentAppVersion =>
      _manualMockVersion ?? _cachedFullVersion;

  static String get version => _version.isNotEmpty
      ? _version
      : DatabaseService.currentAppVersion.split('+').first;

  static String get buildNumber => _buildNumber.isNotEmpty
      ? _buildNumber
      : (DatabaseService.currentAppVersion.contains('+')
          ? DatabaseService.currentAppVersion.split('+').last
          : '');

  /// Reads version asynchronously from PackageInfo with safe offline/test fallback
  static Future<String> getAppVersion() async {
    if (_manualMockVersion != null) {
      return _manualMockVersion!;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
      if (_version.isNotEmpty) {
        _cachedFullVersion =
            _buildNumber.isNotEmpty ? '$_version+$_buildNumber' : _version;
        return _cachedFullVersion;
      }
    } catch (e) {
      debugPrint(
          '⚠️ [AppInfoService] Cannot read PackageInfo (test/offline mode): $e');
    }
    _cachedFullVersion = DatabaseService.currentAppVersion;
    return _cachedFullVersion;
  }

  /// For testing: allows overriding version
  @visibleForTesting
  static void setMockVersion({required String version, String buildNumber = ''}) {
    _version = version;
    _buildNumber = buildNumber;
    _cachedFullVersion =
        buildNumber.isNotEmpty ? '$version+$buildNumber' : version;
    _manualMockVersion = _cachedFullVersion;
  }

  /// For testing: resets to default fallback
  @visibleForTesting
  static void reset() {
    _version = '';
    _buildNumber = '';
    _manualMockVersion = null;
    _cachedFullVersion = DatabaseService.currentAppVersion;
  }
}
