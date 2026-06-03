import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/ruta_model.dart';

class GeolocalizacionService {
  // Coordenadas oficiales de la Tienda de Comercializadora Aly
  static const double tiendaLat = -12.056593;
  static const double tiendaLng = -75.237897;

  // API Key de Google Maps
  static const String mapsApiKey = 'AIzaSyBIZrptkE0IGakPhzMzMpq4PaW_gw_D1vk';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://maps.googleapis.com/maps/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene la ruta entre dos puntos (coordenadas) usando Google Directions API,
  /// guarda el resultado en la colección 'geolocalizacion_rutas' en Firestore y
  /// retorna el objeto de datos [RutaModel].
  Future<RutaModel?> obtenerRuta({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    String? usuarioId,
    String tipo = 'otro',
  }) async {
    try {
      debugPrint('🌐 Maps API: Consultando ruta desde ($origenLat,$origenLng) hasta ($destinoLat,$destinoLng)...');

      final response = await _dio.get(
        '/directions/json',
        queryParameters: {
          'origin': '$origenLat,$origenLng',
          'destination': '$destinoLat,$destinoLng',
          'key': mapsApiKey,
          'mode': 'driving',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final status = data['status']?.toString();

        if (status == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final distancia = leg['distance']['text']?.toString() ?? 'N/A';
          final duracion = leg['duration']['text']?.toString() ?? 'N/A';
          final polyline = route['overview_polyline']['points']?.toString() ?? '';

          // Crear objeto de ruta
          final rutaMap = {
            'origen_lat': origenLat,
            'origen_lng': origenLng,
            'destino_lat': destinoLat,
            'destino_lng': destinoLng,
            'distancia': distancia,
            'duracion': duracion,
            'polyline': polyline,
            'fecha_consulta': FieldValue.serverTimestamp(),
            'usuario_id': usuarioId,
            'tipo': tipo,
          };

          debugPrint('💾 Firestore: Guardando ruta en la colección "geolocalizacion_rutas"...');
          final ref = await _db.collection('geolocalizacion_rutas').add(rutaMap);
          
          debugPrint('✅ Geolocalizacion: Ruta guardada con ID: ${ref.id}');

          return RutaModel(
            id: ref.id,
            origenLat: origenLat,
            origenLng: origenLng,
            destinoLat: destinoLat,
            destinoLng: destinoLng,
            distancia: distancia,
            duracion: duracion,
            polyline: polyline,
            fechaConsulta: DateTime.now(),
            usuarioId: usuarioId,
            tipo: tipo,
          );
        } else {
          debugPrint('⚠️ Maps API retornó un estado de error: $status');
          if (data['error_message'] != null) {
            debugPrint('   Mensaje de error: ${data['error_message']}');
          }
        }
      } else {
        debugPrint('⚠️ Maps API error en respuesta HTTP: ${response.statusCode}');
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Maps API error DioException: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Geolocalizacion: Error general al obtener ruta: $e');
      return null;
    }
  }

  /// Helper rápido para obtener y guardar la ruta de un usuario hacia la tienda física.
  Future<RutaModel?> obtenerRutaHaciaTienda({
    required double usuarioLat,
    required double usuarioLng,
    String? usuarioId,
  }) async {
    return obtenerRuta(
      origenLat: usuarioLat,
      origenLng: usuarioLng,
      destinoLat: tiendaLat,
      destinoLng: tiendaLng,
      usuarioId: usuarioId,
      tipo: 'usuario_a_tienda',
    );
  }

  /// Helper rápido para obtener y guardar la ruta de la tienda física hacia el usuario (delivery).
  Future<RutaModel?> obtenerRutaDesdeTienda({
    required double usuarioLat,
    required double usuarioLng,
    String? usuarioId,
  }) async {
    return obtenerRuta(
      origenLat: tiendaLat,
      origenLng: tiendaLng,
      destinoLat: usuarioLat,
      destinoLng: usuarioLng,
      usuarioId: usuarioId,
      tipo: 'tienda_a_usuario',
    );
  }

  /// Recupera el historial de consultas de geolocalización de un usuario desde Firestore.
  Stream<List<RutaModel>> streamHistorialRutas(String usuarioId) {
    return _db
        .collection('geolocalizacion_rutas')
        .where('usuario_id', isEqualTo: usuarioId)
        .orderBy('fecha_consulta', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RutaModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }
}
