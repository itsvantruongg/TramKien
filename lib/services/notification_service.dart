import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotif {
  final String id, title, body;
  final int targetTab;
  final DateTime ts;
  bool isRead;

  AppNotif(
      {required this.id,
      required this.title,
      required this.body,
      required this.targetTab,
      required this.ts,
      this.isRead = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'targetTab': targetTab,
        'ts': ts.toIso8601String(),
        'isRead': isRead
      };

  static AppNotif fromJson(Map<String, dynamic> j) => AppNotif(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      body: j['body'] ?? '',
      targetTab: j['targetTab'] ?? 0,
      ts: DateTime.parse(j['ts']),
      isRead: j['isRead'] ?? false);
}

class NotificationService {
  static String _currentMssv = '';

  // ── Serial lock để tránh race condition khi ghi đồng thời ──
  static Future<void>? _pendingWrite;

  static void setMssv(String mssv) {
    _currentMssv = mssv;
  }

  static String get _key =>
      'app_notifications_v2${_currentMssv.isNotEmpty ? '_$_currentMssv' : ''}';

  static String get _dismissedKey =>
      'dismissed_notifications_${_currentMssv.isNotEmpty ? '_$_currentMssv' : ''}';

  // ── Dismissed IDs ────────────────────────────────────────────

  static Future<List<String>> getDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_dismissedKey) ?? [];
  }

  /// Thêm nhiều ID cùng lúc để giảm số lần ghi vào disk
  static Future<void> addDismissedIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_dismissedKey) ?? [];
    for (final id in ids) {
      if (!list.contains(id)) list.add(id);
    }
    // Giới hạn 200 ID gần nhất (rolling window)
    await prefs.setStringList(_dismissedKey,
        list.length > 200 ? list.sublist(list.length - 200) : list);
  }

  // ── Read ─────────────────────────────────────────────────────

  static Future<List<AppNotif>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List)
          .map((j) => AppNotif.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<int> unreadCount() async =>
      (await getAll()).where((n) => !n.isRead).length;

  // ── Write (Serial – chống race condition) ────────────────────

  /// Thực thi thao tác ghi theo hàng đợi tuần tự để tránh race condition.
  /// Mọi thao tác ghi phải đi qua hàm này.
  static Future<void> _serialWrite(Future<void> Function() action) async {
    // Chờ tác vụ trước hoàn thành rồi mới chạy tác vụ tiếp theo
    final previous = _pendingWrite;
    final completer = Completer<void>();
    _pendingWrite = completer.future;
    try {
      if (previous != null) await previous.catchError((_) {});
      await action();
    } finally {
      completer.complete();
    }
  }

  /// Thêm thông báo mới. Kiểm tra trùng lặp theo ID (chính xác hơn title+time).
  static Future<void> add(AppNotif n) => _serialWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await getAll();

        // Kiểm tra trùng theo ID – chính xác và không bị nhầm lẫn giữa các loại thông báo
        if (list.any((x) => x.id == n.id)) return;

        list.insert(0, n);
        await prefs.setString(
            _key, jsonEncode(list.take(100).map((x) => x.toJson()).toList()));
      });

  /// Xóa một thông báo theo ID và lưu ID vào dismissed để không tạo lại.
  static Future<void> removeOne(String id) => _serialWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await getAll();
        list.removeWhere((n) => n.id == id);
        await prefs.setString(
            _key, jsonEncode(list.map((x) => x.toJson()).toList()));
        // Đánh dấu đã dismissed
        await addDismissedIds([id]);
      });

  static Future<void> markAllRead() => _serialWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await getAll();
        for (final n in list) n.isRead = true;
        await prefs.setString(
            _key, jsonEncode(list.map((x) => x.toJson()).toList()));
      });

  static Future<void> markRead(String id) => _serialWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await getAll();
        final idx = list.indexWhere((n) => n.id == id);
        if (idx != -1) {
          list[idx].isRead = true;
          await prefs.setString(
              _key, jsonEncode(list.map((x) => x.toJson()).toList()));
        }
      });

  /// Xóa tất cả và đưa toàn bộ ID hiện tại vào dismissed (ghi 1 lần).
  static Future<void> clearAll() => _serialWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        final currentNotifs = await getAll();
        // Batch: lưu tất cả ID vào dismissed cùng một lần
        await addDismissedIds(currentNotifs.map((n) => n.id).toList());
        await prefs.remove(_key);
      });

  // ── Seeding Mock Data (Admin Only) ──────────────────────────
  static Future<void> seedMockData() async {
    final now = DateTime.now();
    final mockNotifs = [
      AppNotif(
        id: 'mock_grade_1',
        title: 'Có điểm mới môn Lập trình Mobile',
        body: 'Điểm tổng kết: 8.5 (A). Chúc mừng bạn!',
        targetTab: 2,
        ts: now.subtract(const Duration(hours: 2)),
      ),
      AppNotif(
        id: 'mock_lich_1',
        title: 'Lịch học ngày mai',
        body: 'Bạn có 2 ca học: Thiết kế đồ họa (P.301) và Tiếng Anh (P.202)',
        targetTab: 1,
        ts: now.subtract(const Duration(hours: 5)),
      ),
      AppNotif(
        id: 'mock_finance_1',
        title: 'Thanh toán thành công',
        body: 'Hệ thống đã nhận 2.500.000đ học phí đợt 2 của bạn.',
        targetTab: 3,
        ts: now.subtract(const Duration(days: 1)),
      ),
      AppNotif(
        id: 'mock_thi_1',
        title: 'Thông báo lịch thi',
        body: 'Lịch thi môn Cơ sở dữ liệu đã được cập nhật vào ngày 15/05.',
        targetTab: 1,
        ts: now.subtract(const Duration(days: 2)),
      ),
      AppNotif(
        id: 'mock_system_1',
        title: 'Cập nhật ứng dụng',
        body: 'Phiên bản 2.0 đã sẵn sàng với nhiều tính năng mới.',
        targetTab: 0,
        ts: now.subtract(const Duration(days: 3)),
      ),
    ];

    await _serialWrite(() async {
      final prefs = await SharedPreferences.getInstance();

      // 1. Xóa các ID giả lập khỏi danh sách dismissed_ids để chúng có thể "hồi sinh"
      final dismissed = prefs.getStringList(_dismissedKey) ?? [];
      final mockIds = mockNotifs.map((n) => n.id).toSet();
      dismissed.removeWhere((id) => mockIds.contains(id));
      await prefs.setStringList(_dismissedKey, dismissed);

      // 2. Ghi đè danh sách thông báo hiện tại bằng dữ liệu giả lập (Khớp định dạng JSON String)
      final jsonData = jsonEncode(mockNotifs.map((n) => n.toJson()).toList());
      await prefs.setString(_key, jsonData);
    });
  }
}
