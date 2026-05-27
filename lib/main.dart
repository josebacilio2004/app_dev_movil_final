import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/seeders/seeder_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Localización para evitar errores de Intl en Web
  await initializeDateFormatting('es_PE', null);

  // Inicializar Notificaciones Locales
  await NotificationService().init();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Ejecutar seeders después de inicializar Firebase
    await SeederInitializer.initCatalogo();
    await SeederInitializer.seedTestUsers();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: AlyApp(),
    ),
  );
}

class AlyApp extends StatelessWidget {
  const AlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comercializadora Aly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.industrialTheme,
      home: const LoginScreen(),
    );
  }
}
