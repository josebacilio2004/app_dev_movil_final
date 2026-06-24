import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const String _k1 = 'AQ.Ab8RN';
  static const String _k2 = '6KEY5XcbYmuq';
  static const String _k3 = 'Hp7b7dsYcM18J';
  static const String _k4 = 'rysS-Z6rOzSQcHHWczdA';
  
  String get _apiKey => '$_k1$_k2$_k3$_k4';
  
  final String _model = 'gemini-2.5-flash';
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<String> chat({required List<Map<String, String>> history}) async {
    try {
      final String url = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';
      
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
      debugPrint('Gemini API Error (trying fallback 1.5-flash): $e');
      
      // Fallback to 1.5-flash
      try {
        final String fallbackUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey';
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
                  'text': 'Eres el Asistente Técnico IA de Comercializadora Aly, una empresa de herramientas industriales y alineación. Ayuda a resolver dudas de torque, plomado, nivelación y productos. Responde con tono profesional en español.'
                }
              ]
            }
          },
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
      }
      return 'Error de comunicación con la IA de Gemini. Por favor, verifique su API Key o conexión de red.';
    }
  }
}
