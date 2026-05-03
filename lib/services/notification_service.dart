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

  static void setMssv(String mssv) {
    _currentMssv = mssv;
  }

  static String get _key =>
      'app_notifications_v2${_currentMssv.isNotEmpty ? '_$_currentMssv' : ''}';

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

  static Future<void> add(AppNotif n) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final isDupe = list.any((x) =>
        x.title == n.title && DateTime.now().difference(x.ts).inMinutes < 5);
    if (isDupe) return;
    list.insert(0, n);
    await prefs.setString(
        _key, jsonEncode(list.take(40).map((x) => x.toJson()).toList()));
  }

  static Future<int> unreadCount() async =>
      (await getAll()).where((n) => !n.isRead).length;

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    for (final n in list) n.isRead = true;
    await prefs.setString(
        _key, jsonEncode(list.map((x) => x.toJson()).toList()));
  }

  static Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final idx = list.indexWhere((n) => n.id == id);
    if (idx != -1) {
      list[idx].isRead = true;
      await prefs.setString(
          _key, jsonEncode(list.map((x) => x.toJson()).toList()));
    }
  }

  static Future<void> clearAll() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
