import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/dni_resultado.dart';

class ReniecService {
  // Token de APIs Perú provisto por el usuario (se limpió el caracter %27 al final)
  static String apiToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpmY2M5NTAxMjMwOUBnbWFpbC5jb20ifQ.UaK6eecpbt-mVnF9hI-BYSHtl6QQ5hCLU1MNItWe9P8';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://dniruc.apisperu.com/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Consulta los datos de un DNI peruano en la API de APIs Perú.
  /// Retorna un objeto [DniResultado] si tiene éxito o [null] si falla.
  Future<DniResultado?> consultarDNI(String dni, {String? customToken}) async {
    final token = (customToken != null && customToken.trim().isNotEmpty) 
        ? customToken.trim() 
        : apiToken;

    if (dni.length != 8 || int.tryParse(dni) == null) {
      debugPrint('⚠️ ReniecService: DNI inválido. Debe tener exactamente 8 números.');
      return null;
    }

    try {
      debugPrint('🌐 ReniecService: Consultando DNI: $dni...');
      final response = await _dio.get(
        '/dni/$dni',
        queryParameters: {
          'token': token,
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData != null) {
          debugPrint('✅ ReniecService: DNI encontrado con éxito.');
          return DniResultado.fromJson(responseData);
        }
      }
      
      debugPrint('⚠️ ReniecService: Error en la respuesta. Código: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      debugPrint('❌ ReniecService: Error de conexión DioException: ${e.message}');
      if (e.response != null) {
        debugPrint('   Respuesta del servidor: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      debugPrint('❌ ReniecService: Error desconocido al consultar DNI: $e');
      return null;
    }
  }
}
