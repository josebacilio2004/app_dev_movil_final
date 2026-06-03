import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurar que Firebase esté inicializado en segundo plano
  await Firebase.initializeApp();
  debugPrint('📩 FCM Background Message: ${message.messageId}');
  if (message.notification != null) {
    debugPrint('   Title: ${message.notification!.title}');
    debugPrint('   Body: ${message.notification!.body}');
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      // 1. Solicitar permisos de notificación (Requerido en iOS y Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 FCM Permission Status: ${settings.authorizationStatus}');

      // 2. Obtener y loguear el Token FCM
      String? token;
      try {
        if (kIsWeb) {
          token = await _fcm.getToken(
            vapidKey: 'BDbQ9Gq4xI_...' // Opcional: clave VAPID pública para web push
          );
        } else {
          token = await _fcm.getToken();
        }
        debugPrint('🔑 FCM Token: $token');
      } catch (tokenError) {
        debugPrint('⚠️ FCM: No se pudo obtener el token en esta plataforma/entorno: $tokenError');
      }

      // 3. Registrar el callback para mensajes en segundo plano (Background/Terminated state)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Escuchar notificaciones en primer plano (Foreground state)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 FCM Foreground Message: ${message.messageId}');
        
        final notification = message.notification;
        if (notification != null) {
          // Mostrar notificación local usando nuestro servicio local
          NotificationService().showNotification(
            id: notification.hashCode,
            title: notification.title ?? 'Notificación',
            body: notification.body ?? '',
          );
        }
      });

      // 5. Manejar click en notificación cuando la app se abre desde segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🎯 FCM Message opened app: ${message.messageId}');
      });

    } catch (e) {
      debugPrint('⚠️ PushNotificationService Error: $e');
    }
  }
}
