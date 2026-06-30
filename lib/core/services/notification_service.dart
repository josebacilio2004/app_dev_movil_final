import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Manejar click en notificación si es necesario
      },
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // 1. Guardar en el historial local siempre para la bandeja interna
    await _saveToHistory(id, title, body);

    // 2. Verificar preferencia de notificaciones antes de disparar alerta nativa
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) {
        debugPrint('🚫 Notificación nativa omitida por preferencia del usuario: $title');
        return;
      }
    } catch (e) {
      debugPrint('Error leyendo preferencia de notificaciones: $e');
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'billing_alerts',
      'Alertas de Facturación',
      channelDescription: 'Notificaciones sobre facturas vencidas o próximas a vencer',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> _saveToHistory(int id, String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('notifications_history');
      List<dynamic> history = [];
      if (historyStr != null) {
        try {
          history = jsonDecode(historyStr);
        } catch (_) {}
      }
      history.insert(0, {
        'id': '${DateTime.now().millisecondsSinceEpoch}_$id',
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });
      if (history.length > 100) {
        history = history.sublist(0, 100);
      }
      await prefs.setString('notifications_history', jsonEncode(history));
    } catch (e) {
      debugPrint('Error guardando en historial: $e');
    }
  }
}
