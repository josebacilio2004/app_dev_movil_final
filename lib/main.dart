import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/home_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/seeders/seeder_initializer.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/google_drive_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/push_notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar URL guardada de Google Drive
  await GoogleDriveService.loadPersistedUrl();
  
  // Inicialización de Localización para evitar errores de Intl en Web
  await initializeDateFormatting('es_PE', null);

  // Inicializar Notificaciones Locales
  await NotificationService().init();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar persistencia caché offline para Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    // Inicializar Notificaciones Push (FCM)
    await PushNotificationService().init();
    
    // Ejecutar seeders en segundo plano sin bloquear el hilo principal de renderizado
    _runSeedersIfNeeded();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
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

class AlyApp extends ConsumerWidget {
  const AlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLoginAsync = ref.watch(autoLoginProvider);

    return MaterialApp(
      title: 'Comercializadora Aly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.industrialTheme,
      home: autoLoginAsync.when(
        data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
        loading: () => const Scaffold(
          backgroundColor: AppTheme.primaryDark,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          ),
        ),
        error: (err, stack) => const LoginScreen(),
      ),
    );
  }
}
