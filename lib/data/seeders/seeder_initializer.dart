import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/firestore_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/seeders/product_seeder.dart';

/// Inicializador del Seeder — ejecuta una única vez para poblar el catálogo
class SeederInitializer {
  static bool _hasRun = false;

  /// Ejecuta el seeder de catálogo si la colección está vacía.
  /// Retorna true si se ejecutó el seeder, false si ya existía data.
  static Future<bool> initCatalogo() async {
    if (_hasRun) return false;
    _hasRun = true;

    try {
      final service = FirestoreService();
      
      // Verificar si ya está sembrado
      final alreadySeeded = await service.isCatalogoSeeded();
      if (alreadySeeded) {
        debugPrint('ℹ️ Seeder: El catálogo ya está inicializado (45 productos). Omitiendo resembrado.');
        return false;
      }
      
      debugPrint('🌱 Limpiando catálogo antiguo y ejecutando nuevo seeder (45 productos)...');
      await service.clearCatalogoProductos();
      
      final productos = ProductSeeder.generarCatalogo();
      final count = await service.seedCatalogoProductos(productos);
      debugPrint('✅ Seeder completado: $count productos insertados de forma limpia.');
      return true;
    } catch (e) {
      debugPrint('❌ Error en seeder: $e');
      return false;
    }
  }

  /// Crea usuarios de prueba en Firebase Auth y Firestore (perfiles)
  static Future<void> seedTestUsers() async {
    try {
      final service = FirestoreService();
      final auth = FirebaseAuth.instance;

      final testUsers = [
        {
          'nombre': 'Admin Prueba',
          'usuario': 'admin_aly',
          'email': 'admin_aly@comercializadoraaly.com',
          'rol': 'admin',
          'activo': true,
        },
        {
          'nombre': 'Carlos Mendoza',
          'usuario': 'inv_carlos',
          'email': 'inversionista@comercializadoraaly.com',
          'rol': 'inversionista',
          'activo': true,
        },
        {
          'nombre': 'María López',
          'usuario': 'comp_maria',
          'email': 'comprador@comercializadoraaly.com',
          'rol': 'comprador',
          'activo': true,
        },
        {
          'nombre': 'Pedro Quispe',
          'usuario': 'oper_pedro',
          'email': 'operador@comercializadoraaly.com',
          'rol': 'operador',
          'activo': true,
        },
      ];

      const defaultPassword = 'password123';

      for (final user in testUsers) {
        final email = user['email'] as String;
        final nombre = user['nombre'] as String;
        final rol = user['rol'] as String;

        try {
          debugPrint('🌱 Intentando crear usuario Firebase Auth para: $email...');
          final credential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: defaultPassword,
          );
          
          final uid = credential.user!.uid;
          await service.createUserProfile(uid, Map<String, dynamic>.from(user));
          debugPrint('✅ Usuario creado en Auth y Firestore: $nombre ($rol) -> UID: $uid');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            debugPrint('ℹ️ El correo $email ya está registrado en Firebase Auth.');
            // Intentamos loguearnos para obtener su UID y crear el perfil si no existe en Firestore
            try {
              final credential = await auth.signInWithEmailAndPassword(
                email: email,
                password: defaultPassword,
              );
              final uid = credential.user!.uid;
              final existingProfile = await service.getUserByUid(uid);
              if (existingProfile == null) {
                await service.createUserProfile(uid, Map<String, dynamic>.from(user));
                debugPrint('✅ Perfil Firestore creado para usuario existente: $nombre ($rol)');
              } else {
                debugPrint('ℹ️ Perfil Firestore ya existe para: $nombre ($rol)');
              }
            } catch (loginErr) {
              debugPrint('⚠️ Error al verificar/loguear usuario existente $email: $loginErr');
            }
          } else {
            debugPrint('⚠️ Error creando usuario Auth para $email: ${e.message}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error creando usuarios de prueba: $e');
    }
  }
}
