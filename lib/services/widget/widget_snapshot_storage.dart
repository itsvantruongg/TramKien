import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/widget_schedule_snapshot.dart';

/// Quản lý đọc, ghi và xóa file bản chụp JSON lịch học (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01)
class WidgetSnapshotStorage {
  static const String snapshotFileName = 'widget_schedule_snapshot.json';
  static const MethodChannel _widgetChannel =
      MethodChannel('com.tramkien.hau/widget');

  /// Hàng đợi tuần tự đảm bảo các lần ghi không bị tranh chấp tài nguyên (mutex)
  static Future<void> _sequentialLock = Future.value();

  /// Thư mục cơ sở tùy chỉnh dùng cho testing / mock
  final Directory? customBaseDir;

  const WidgetSnapshotStorage({this.customBaseDir});

  /// Lấy thư mục lưu trữ chia sẻ chuẩn của nền tảng:
  /// - Android: context.filesDir (qua getApplicationSupportDirectory)
  /// - iOS: App Group container (group.vn.edu.hau.tramkien)
  Future<Directory> resolveSharedDirectory() async {
    if (customBaseDir != null) {
      if (!await customBaseDir!.exists()) {
        await customBaseDir!.create(recursive: true);
      }
      return customBaseDir!;
    }

    // Trên iOS: Ưu tiên App Group container để WidgetKit có thể đọc trực tiếp
    if (!kIsWeb && Platform.isIOS) {
      try {
        final appGroupPath = await _widgetChannel
            .invokeMethod<String>('getAppGroupDirectory')
            .timeout(const Duration(milliseconds: 500));
        if (appGroupPath != null && appGroupPath.isNotEmpty) {
          final dir = Directory(appGroupPath);
          if (await dir.exists()) {
            return dir;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [WidgetSnapshotStorage] Cannot get App Group directory: $e');
      }
    }

    // Android hoặc fallback iOS
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        return docsDir;
      } catch (_) {
        final tempDir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}tramkien_widget');
        if (!await tempDir.exists()) {
          await tempDir.create(recursive: true);
        }
        return tempDir;
      }
    }
  }

  /// Lấy đường dẫn file bản chụp lịch
  Future<File> getSnapshotFile({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      return File(customPath);
    }
    final dir = await resolveSharedDirectory();
    final separator = Platform.pathSeparator;
    return File('${dir.path}$separator$snapshotFileName');
  }

  /// Ghi bản chụp lịch ra file JSON tuần tự và an toàn tuyệt đối (Atomic Write)
  Future<File> saveSnapshot(
    WidgetScheduleSnapshot snapshot, {
    String? customPath,
  }) async {
    final prevLock = _sequentialLock;
    final completer = Completer<void>();
    _sequentialLock = completer.future;

    try {
      await prevLock;
      return await _saveSnapshotInternal(snapshot, customPath: customPath);
    } finally {
      completer.complete();
    }
  }

  Future<File> _saveSnapshotInternal(
    WidgetScheduleSnapshot snapshot, {
    String? customPath,
  }) async {
    final file = await getSnapshotFile(customPath: customPath);
    final jsonStr = snapshot.toJsonString();

    // Tạo thư mục cha nếu chưa có
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // Ghi an toàn qua file tạm duy nhất theo microsecond để không bị xung đột
    final tempFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tempFile.writeAsString(jsonStr, flush: true);
      if (!kIsWeb && Platform.isWindows) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      await tempFile.rename(file.path);
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }

    debugPrint('💾 [WidgetSnapshotStorage] Saved snapshot with ${snapshot.sessions.length} sessions to ${file.path}');
    return file;
  }

  /// Đọc bản chụp lịch từ file JSON
  /// Xử lý đầy đủ các trường hợp:
  /// - File chưa tồn tại -> trả về null
  /// - File hỏng (syntax error, version != 1) -> log warning, trả về null, tuyệt đối không crash
  /// - File quá cũ (> maxAge) -> trả về null nếu enforceNotStale = true
  Future<WidgetScheduleSnapshot?> readSnapshot({
    String? customPath,
    Duration maxAge = const Duration(days: 14),
    bool enforceNotStale = false,
    DateTime? now,
  }) async {
    try {
      final file = await getSnapshotFile(customPath: customPath);
      if (!await file.exists()) {
        debugPrint('ℹ️ [WidgetSnapshotStorage] Snapshot file does not exist at ${file.path}');
        return null;
      }

      final jsonStr = await file.readAsString();
      if (jsonStr.trim().isEmpty) {
        debugPrint('⚠️ [WidgetSnapshotStorage] Snapshot file is empty');
        return null;
      }

      final snapshot = WidgetScheduleSnapshot.fromJsonString(jsonStr);

      if (!snapshot.isValid) {
        debugPrint('⚠️ [WidgetSnapshotStorage] Invalid snapshot version: ${snapshot.version}');
        return null;
      }

      if (enforceNotStale && snapshot.isStale(maxAge: maxAge, now: now)) {
        debugPrint('⚠️ [WidgetSnapshotStorage] Snapshot is stale (generatedAt: ${snapshot.generatedAt})');
        return null;
      }

      return snapshot;
    } catch (e, stack) {
      debugPrint('⚠️ [WidgetSnapshotStorage] Error reading snapshot: $e\n$stack');
      return null;
    }
  }

  /// Xóa sạch file bản chụp lịch khi người dùng đăng xuất hoặc chuyển đổi tài khoản
  Future<bool> deleteSnapshot({String? customPath}) async {
    try {
      final file = await getSnapshotFile(customPath: customPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ [WidgetSnapshotStorage] Deleted snapshot file: ${file.path}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [WidgetSnapshotStorage] Error deleting snapshot: $e');
      return false;
    }
  }

  /// Kiểm tra xem file bản chụp có đang tồn tại hay không
  Future<bool> hasSnapshot({String? customPath}) async {
    final file = await getSnapshotFile(customPath: customPath);
    return file.exists();
  }
}
