import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  static const String _prefKey = 'google_drive_apps_script_url';

  // URL por defecto del Google Apps Script Web App. El usuario puede cambiarla aquí o configurarla.
  static String appsScriptUrl = 'https://script.google.com/macros/s/AKfycbyT9DnSN7Du9wET6Lc6B1WonNWMkFWua0XCyyUdtDtrDpkd8Jj5alyc_xMqyzccrcQj/exec';

  final Dio _dio = Dio();

  /// Carga la URL de SharedPreferences.
  static Future<void> loadPersistedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefKey);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        appsScriptUrl = savedUrl.trim();
        debugPrint('🌐 Google Drive Service: URL cargada desde persistencia: $appsScriptUrl');
      }
    } catch (e) {
      debugPrint('❌ Google Drive Service: Error al cargar URL persistida: $e');
    }
  }

  /// Guarda la URL en SharedPreferences.
  static Future<void> persistUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, url.trim());
      appsScriptUrl = url.trim();
      debugPrint('🌐 Google Drive Service: URL guardada en persistencia: $appsScriptUrl');
    } catch (e) {
      debugPrint('❌ Google Drive Service: Error al guardar URL en persistencia: $e');
    }
  }

  /// Sube una imagen a Google Drive a través del script middleware.
  /// Retorna la URL pública de visualización del archivo si tiene éxito.
  Future<String?> uploadImage(Uint8List bytes, String filename, {String? customUrl}) async {
    final url = (customUrl != null && customUrl.trim().isNotEmpty) ? customUrl.trim() : appsScriptUrl;

    if (url.contains('Placeholder_Change_Me')) {
      debugPrint('⚠️ Google Drive: La URL de Apps Script sigue siendo el placeholder.');
      throw Exception('Por favor configura la URL de tu Google Apps Script en la configuración de la app.');
    }

    try {
      final base64Image = base64Encode(bytes);
      final fileExtension = filename.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (fileExtension == 'png') {
        mimeType = 'image/png';
      } else if (fileExtension == 'gif') {
        mimeType = 'image/gif';
      } else if (fileExtension == 'webp') {
        mimeType = 'image/webp';
      }

      final payload = {
        'base64': base64Image,
        'filename': filename,
        'mimeType': mimeType,
      };

      debugPrint('🌐 Google Drive: Enviando imagen a Apps Script... URL: $url');
      Response response = await _dio.post(
        url,
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Content-Type': 'text/plain',
          },
          followRedirects: kIsWeb,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Manejar el redireccionamiento manual para conservar el método POST y cuerpo
      if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null) {
          debugPrint('🌐 Google Drive: Redirigiendo GET a: $redirectUrl');
          response = await _dio.get(
            redirectUrl,
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status != null && status < 500,
            ),
          );
        }
      }

      if (response.statusCode == 200) {
        // En Apps Script, a veces ocurren redireccionamientos que Dio maneja, o retorna el JSON directo
        final responseData = response.data;
        Map<String, dynamic> jsonResponse;
        
        if (responseData is String) {
          jsonResponse = jsonDecode(responseData);
        } else if (responseData is Map) {
          jsonResponse = Map<String, dynamic>.from(responseData);
        } else {
          throw Exception('Formato de respuesta desconocido.');
        }

        if (jsonResponse['status'] == 'success') {
          final imageUrl = jsonResponse['url'] as String;
          debugPrint('✅ Google Drive: Imagen subida con éxito. URL: $imageUrl');
          return imageUrl;
        } else {
          final errorMsg = jsonResponse['message'] ?? 'Error desconocido en Apps Script';
          throw Exception(errorMsg);
        }
      } else {
        throw Exception('Servidor respondió con código: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Google Drive Upload Error: $e');
      rethrow;
    }
  }
}
