import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de Autenticación con Firebase Auth y Firestore
class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  Usuario? _currentUser;

  Usuario? get currentUser => _currentUser;

  /// Inicia sesión con Firebase Auth resolviendo el rol dinámicamente desde Firestore
  Future<Usuario?> signIn(String identifier, String password) async {
    try {
      debugPrint('🔑 Iniciando autenticación en Firebase para: $identifier');
      String email = identifier.trim();
      String resolvedRole = 'comprador';
      String resolvedName = 'Usuario';
      String resolvedUsername = identifier;

      // 1. Buscamos el usuario en Firestore para obtener su email y rol
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      if (email.contains('@')) {
        querySnapshot = await _db
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
      } else {
        querySnapshot = await _db
            .collection('users')
            .where('usuario', isEqualTo: email)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ Usuario no encontrado en Firestore: $identifier');
        return null;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      email = userData['email'] ?? '';
      resolvedRole = userData['rol'] ?? 'comprador';
      resolvedName = userData['nombre'] ?? 'Usuario';
      resolvedUsername = userData['usuario'] ?? identifier;

      if (email.isEmpty) {
        debugPrint('❌ El correo electrónico está vacío.');
        return null;
      }

      // 2. Autenticación con Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        debugPrint('❌ UID de usuario de Firebase es nulo.');
        return null;
      }

      _currentUser = Usuario(
        id: uid,
        nombre: resolvedName,
        usuario: resolvedUsername,
        rol: resolvedRole,
        email: email,
      );

      // 3. Guardar sesión en SharedPreferences para autologin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', uid);
      await prefs.setString('user_name', resolvedName);
      await prefs.setString('user_role', resolvedRole);

      debugPrint('🔑 Sesión iniciada con éxito: ${_currentUser!.nombre} (${_currentUser!.rol})');
      return _currentUser;
    } catch (e) {
      debugPrint('❌ Error en signIn de AuthService: $e');
      return null;
    }
  }

  /// Registra un nuevo usuario en Firebase Auth y crea su perfil en Firestore
  Future<Usuario?> signUp({
    required String email,
    required String password,
    required String nombre,
    required String usuario,
    required String rol,
    String? dni,
  }) async {
    try {
      debugPrint('🆕 Registrando usuario en Firebase Auth: $email...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        debugPrint('❌ UID de usuario de Firebase es nulo después de registrar.');
        return null;
      }

      // Guardar perfil en Firestore
      debugPrint('💾 Guardando perfil en Firestore para UID: $uid...');
      await _db.collection('users').doc(uid).set({
        'nombre': nombre,
        'usuario': usuario,
        'email': email,
        'rol': rol,
        'dni': dni,
        'activo': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      _currentUser = Usuario(
        id: uid,
        nombre: nombre,
        usuario: usuario,
        rol: rol,
      );

      // Guardar sesión en SharedPreferences para autologin inmediato
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', uid);
      await prefs.setString('user_name', nombre);
      await prefs.setString('user_role', rol);

      return _currentUser;
    } catch (e) {
      debugPrint('❌ Error en signUp de AuthService: $e');
      rethrow;
    }
  }

  /// Cierra sesión de Firebase y limpia el cache
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('⚠️ Error al desloguear de Firebase: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    // Remover solo las claves de sesión activa, preservando huella dactilar (bio_*)
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    _currentUser = null;
    debugPrint('🚪 Sesión cerrada correctamente');
  }

  /// Intenta restaurar sesión de forma automática sincronizándola con Firebase Auth
  Future<Usuario?> tryAutoLogin() async {
    try {
      // 1. Esperar a que Firebase Auth se inicialice y verifique si hay un usuario activo
      final fbUser = await _auth.authStateChanges().first;
      if (fbUser == null) {
        debugPrint('🔄 tryAutoLogin: Firebase Auth indica que no hay sesión activa.');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('user_id');
      if (id == null || id != fbUser.uid) {
        // Cargar datos de Firestore para asegurar la consistencia si no coincide el cache
        final userDoc = await _db.collection('users').doc(fbUser.uid).get();
        if (!userDoc.exists) {
          debugPrint('❌ tryAutoLogin: No se encontró perfil de usuario en Firestore para UID: ${fbUser.uid}');
          return null;
        }
        final userData = userDoc.data()!;
        final name = userData['nombre'] ?? 'Usuario';
        final role = userData['rol'] ?? 'comprador';
        
        _currentUser = Usuario(
          id: fbUser.uid,
          nombre: name,
          usuario: userData['usuario'] ?? '',
          rol: role,
          email: fbUser.email,
        );
        
        await prefs.setString('user_id', fbUser.uid);
        await prefs.setString('user_name', name);
        await prefs.setString('user_role', role);
        
        debugPrint('🔄 Autologin exitoso y sincronizado desde Firestore para: $name ($role)');
        return _currentUser;
      }

      final name = prefs.getString('user_name') ?? '';
      final role = prefs.getString('user_role') ?? 'comprador';

      _currentUser = Usuario(
        id: id,
        nombre: name,
        usuario: '',
        rol: role,
        email: fbUser.email,
      );
      
      debugPrint('🔄 Autologin exitoso para: $name ($role)');
      return _currentUser;
    } catch (e) {
      debugPrint('❌ Error en tryAutoLogin de AuthService: $e');
      return null;
    }
  }
}
