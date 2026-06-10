import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    body: map['body'] ?? '',
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    read: map['read'] ?? false,
  );
}

final notificationHistoryProvider = StateNotifierProvider<NotificationHistoryNotifier, List<AppNotification>>((ref) {
  return NotificationHistoryNotifier();
});

class NotificationHistoryNotifier extends StateNotifier<List<AppNotification>> {
  NotificationHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('notifications_history');
      if (historyStr != null) {
        final List<dynamic> decoded = jsonDecode(historyStr);
        state = decoded.map((m) => AppNotification.fromMap(m)).toList();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> refresh() async {
    await _loadHistory();
  }

  Future<void> addNotification(String title, String body) async {
    final newNotif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    state = [newNotif, ...state];
    await _saveHistory();
  }

  Future<void> markAsRead(String id) async {
    state = state.map((n) {
      if (n.id == id) {
        return AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          read: true,
        );
      }
      return n;
    }).toList();
    await _saveHistory();
  }

  Future<void> clearAll() async {
    state = [];
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = state.map((n) => n.toMap()).toList();
      await prefs.setString('notifications_history', jsonEncode(serialized));
    } catch (e) {
      // ignore
    }
  }
}
