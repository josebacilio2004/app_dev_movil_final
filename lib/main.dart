import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/seeders/seeder_initializer.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/google_drive_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/push_notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/firestore_service.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/splash_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/session_timeout_listener.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar URL guardada de Google Drive
  await GoogleDriveService.loadPersistedUrl();
  
  // Inicialización de Localización para evitar errores de Intl en Web
  try {
    await initializeDateFormatting('es_PE', null);
  } catch (e) {
    debugPrint('⚠️ Error al inicializar formato de fecha (intl): $e');
  }

  // Inicializar Notificaciones Locales
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Error al inicializar Notificaciones Locales: $e');
  }
  
  try {
    // Inicializar Firebase solo si no ha sido inicializado previamente para evitar DuplicateAppException
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Configurar persistencia caché offline para Firestore de forma segura
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (firestoreSettingsError) {
      // Ocurre si Firestore ya se usó/inicializó antes de setear las configuraciones
      debugPrint('ℹ️ Firestore settings ya configurados o no se pudieron modificar: $firestoreSettingsError');
    }
    
    // Inicializar Notificaciones Push (FCM)
    try {
      await PushNotificationService().init();
    } catch (fcmError) {
      debugPrint('⚠️ Error al inicializar FCM Push Notifications: $fcmError');
    }
    
    // Ejecutar seeders en segundo plano sin bloquear el hilo principal de renderizado
    _runSeedersIfNeeded();
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: AlyApp(),
    ),
  );
}

/// Helper para verificar y ejecutar el sembrado de datos en segundo plano sin bloquear la UI
void _runSeedersIfNeeded() async {
  try {
    final service = FirestoreService();
    final alreadySeeded = await service.isCatalogoSeeded();
    if (!alreadySeeded) {
      debugPrint('🌱 Catálogo no detectado o incompleto en Firestore. Iniciando sembrado en segundo plano...');
      final seeded = await SeederInitializer.initCatalogo();
      if (seeded) {
        await SeederInitializer.seedTestUsers();
        debugPrint('✅ Sembrado inicial de catálogo y usuarios completado con éxito.');
      }
    } else {
      debugPrint('ℹ️ Catálogo ya sembrado en Firestore (45 productos). Saltando inicialización para mejorar rendimiento.');
    }
  } catch (e) {
    debugPrint('⚠️ Error al verificar/sembrar base de datos en segundo plano: $e');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AlyApp extends ConsumerWidget {
  const AlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeSetting = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Comercializadora Aly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.industrialTheme,
      themeMode: themeModeSetting,
      navigatorKey: navigatorKey,
      builder: (context, child) => SessionTimeoutListener(child: child!),
      home: const SplashScreen(),
    );
  }
}
