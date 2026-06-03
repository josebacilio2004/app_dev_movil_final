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
      debugPrint('🌐 Mapbox Directions API: Consultando ruta desde ($origenLat,$origenLng) hasta ($destinoLat,$destinoLng)...');

      // Mapbox expects coordinates in longitude,latitude format separated by semicolon
      final String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$origenLng,$origenLat;$destinoLng,$destinoLat';
      
      final response = await _dio.get(
        url,
        queryParameters: {
          'geometries': 'polyline',
          'overview': 'full',
          'access_token': 'pk.eyJ1Ijoiam9zZWJhYyIsImEiOiJjbW9pYTU0MW8wMGM4MnNvZ3NhOHo1NWM4In0.5Gw3E-h62DwI4ks5Y70cDw',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final double distanceMeters = (leg['distance'] as num).toDouble();
          final double durationSeconds = (leg['duration'] as num).toDouble();

          final String distancia = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
          final String duracion = '${(durationSeconds / 60).toStringAsFixed(0)} min';
          final String polyline = route['geometry']?.toString() ?? '';

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
          debugPrint('⚠️ Mapbox API no retornó un estado Ok: ${data['code']}');
        }
      } else {
        debugPrint('⚠️ Mapbox API error en respuesta HTTP: ${response.statusCode}');
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Mapbox API error DioException: ${e.message}');
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
