import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _k1 = 'AQ.Ab8RN';
  static const String _k2 = '6KEY5XcbYmuq';
  static const String _k3 = 'Hp7b7dsYcM18J';
  static const String _k4 = 'rysS-Z6rOzSQcHHWczdA';
  
  String get _defaultApiKey => '$_k1$_k2$_k3$_k4';
  
  final String _model = 'gemini-2.5-flash';
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<String> _getApiKey() async {
    try {
      final doc = await _db.collection('config').doc('gemini').get();
      if (doc.exists) {
        final key = doc.data()?['apiKey'];
        if (key != null && (key as String).trim().isNotEmpty) {
          debugPrint('🔑 Usando API Key de Gemini desde Firestore.');
          return key.trim();
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener la API Key de Firestore, usando llave por defecto: $e');
    }
    return _defaultApiKey;
  }

  Future<String> chat({required List<Map<String, String>> history}) async {
    final apiKey = await _getApiKey();
    try {
      final String url = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey';
      
      final contents = history.map((msg) {
        return {
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['text']}
          ]
        };
      }).toList();

      final response = await _dio.post(
        url,
        data: {
          'contents': contents,
          'systemInstruction': {
            'parts': [
              {
                'text': 'Eres el Asistente Técnico IA de Comercializadora Aly, una empresa líder en venta de herramientas industriales, niveladores digitales y equipos de alineación. Tu objetivo es ayudar a los clientes y operarios a calcular torques, resolver dudas técnicas sobre nivelación, recomendar herramientas del catálogo y brindar asesoría industrial de alta calidad. Responde siempre en español, con un tono profesional, técnico, servicial y usando emojis de herramientas de vez en cuando.'
              }
            ]
          }
        },
        options: Options(contentType: 'application/json'),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final parts = data['candidates']?[0]?['content']?['parts'];
        if (parts != null && (parts as List).isNotEmpty) {
          final text = parts[0]['text'];
          if (text != null) {
            return text.toString().trim();
          }
        }
      }
      return 'Lo siento, no pude procesar la respuesta en este momento. Intente de nuevo.';
    } catch (e) {
      debugPrint('Gemini API Error (trying fallback gemini-flash-latest): $e');
      if (e is DioException) {
        debugPrint('Gemini Primary Response Data: ${e.response?.data}');
      }
      
      // Fallback to gemini-flash-latest (valid model name for Gemini 1.5 Flash in this project)
      try {
        final String fallbackUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey';
        final contents = history.map((msg) {
          return {
            'role': msg['role'] == 'user' ? 'user' : 'model',
            'parts': [
              {'text': msg['text']}
            ]
          };
        }).toList();

        final response = await _dio.post(
          fallbackUrl,
          data: {
            'contents': contents,
            'systemInstruction': {
              'parts': [
                {
                  'text': 'Eres el Asistente Técnico IA de Comercializadora Aly, una empresa líder en venta de herramientas industriales, niveladores digitales y equipos de alineación. Tu objetivo es ayudar a los clientes y operarios a calcular torques, resolver dudas técnicas sobre nivelación, recomendar herramientas del catálogo y brindar asesoría industrial de alta calidad. Responde siempre en español, con un tono profesional, técnico, servicial y usando emojis de herramientas de vez en cuando.'
                }
              ]
            }
          },
          options: Options(contentType: 'application/json'),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final parts = data['candidates']?[0]?['content']?['parts'];
          if (parts != null && (parts as List).isNotEmpty) {
            final text = parts[0]['text'];
            if (text != null) {
              return text.toString().trim();
            }
          }
        }
      } catch (err) {
        debugPrint('Gemini Fallback Error: $err');
        if (err is DioException) {
          debugPrint('Gemini Fallback Response Data: ${err.response?.data}');
        }
      }
      return 'Error de comunicación con la IA de Gemini. Por favor, verifique su API Key o conexión de red.';
    }
  }
}
