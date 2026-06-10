import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

final connectionProvider = StateNotifierProvider<ConnectionNotifier, bool>((ref) {
  return ConnectionNotifier();
});

class ConnectionNotifier extends StateNotifier<bool> {
  Timer? _timer;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  ConnectionNotifier() : super(true) {
    _checkConnection();
    // Validar conexión cada 5 segundos de forma pasiva
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    try {
      if (kIsWeb) {
        // En Web, evitamos CORS consultando el logo local con un cache-buster
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final response = await _dio.get('assets/logo.png?t=$timestamp');
        if (response.statusCode == 200) {
          if (state == false) state = true;
        } else {
          if (state == true) state = false;
        }
      } else {
        // En móviles, hacemos un ping rápido a Google
        final response = await _dio.get('https://www.google.com');
        if (response.statusCode == 200) {
          if (state == false) state = true;
        } else {
          if (state == true) state = false;
        }
      }
    } catch (e) {
      if (state == true) {
        state = false;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
