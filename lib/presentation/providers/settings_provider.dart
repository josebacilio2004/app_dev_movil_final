import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Definición legacy de AutoLogoutPolicy para evitar romper código temporalmente antes de limpiar
enum AutoLogoutPolicy {
  inactivity,
  minimize,
  both,
  disabled
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode') ?? 'dark';
      state = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isLight) async {
    final mode = isLight ? ThemeMode.light : ThemeMode.dark;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class NotificationsNotifier extends StateNotifier<bool> {
  NotificationsNotifier() : super(true) {
    _loadNotificationsSetting();
  }

  Future<void> _loadNotificationsSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('notifications_enabled') ?? true;
    } catch (_) {}
  }

  Future<void> toggleNotifications(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (_) {}
  }
}

final notificationsEnabledProvider = StateNotifierProvider<NotificationsNotifier, bool>((ref) {
  return NotificationsNotifier();
});
