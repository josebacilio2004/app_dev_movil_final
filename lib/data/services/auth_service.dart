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

  /// Inicia sesión con Firebase Auth
  /// Si el identificador es un nombre de usuario (sin @), busca en Firestore su email
  Future<Usuario?> signIn(String identifier, String password, String apiRole, {String? originalRole}) async {
    try {
      debugPrint('🔑 Iniciando autenticación en Firebase para: $identifier (Rol: $originalRole)');
      String email = identifier.trim();

      // 1. Si no es un email, buscamos el email asociado al nombre de usuario en Firestore
      if (!email.contains('@')) {
        final querySnapshot = await _db
            .collection('users')
            .where('usuario', isEqualTo: identifier.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          debugPrint('❌ Nombre de usuario no encontrado en Firestore: $identifier');
          return null;
        }

        final userDoc = querySnapshot.docs.first;
        email = userDoc.data()['email'] ?? '';
        debugPrint('📧 Email resuelto de Firestore: $email');
      }

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

      // 3. Obtener el perfil del usuario desde Firestore
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        debugPrint('❌ No se encontró el perfil de usuario en Firestore para UID: $uid');
        return null;
      }

      final userData = userDoc.data()!;
      final String userRole = originalRole ?? (userData['rol'] ?? apiRole);

      _currentUser = Usuario.fromJson({
        'id': uid,
        'nombre': userData['nombre'] ?? 'Usuario',
        'usuario': userData['usuario'] ?? identifier,
        'rol': userRole,
        'email': email,
      });

      // 4. Guardar sesión en SharedPreferences para autologin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.id);
      await prefs.setString('user_name', _currentUser!.nombre);
      await prefs.setString('user_role', userRole);

      debugPrint('✅ Sesión iniciada con éxito: ${_currentUser!.nombre} (${_currentUser!.rol})');
      return _currentUser;
    } catch (e) {
      debugPrint('❌ Error en signIn de AuthService: $e');
      return null;
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
    await prefs.clear();
    _currentUser = null;
    debugPrint('🚪 Sesión cerrada correctamente');
  }

  /// Intenta restaurar sesión de forma automática
  Future<Usuario?> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    if (id == null) return null;

    final name = prefs.getString('user_name') ?? '';
    final role = prefs.getString('user_role') ?? 'usuario';

    _currentUser = Usuario(
      id: id,
      nombre: name,
      usuario: '',
      rol: role,
    );
    
    debugPrint('🔄 Autologin exitoso para: $name ($role)');
    return _currentUser;
  }
}
