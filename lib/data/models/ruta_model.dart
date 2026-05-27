import 'package:cloud_firestore/cloud_firestore.dart';

class RutaModel {
  final String id;
  final double origenLat;
  final double origenLng;
  final double destinoLat;
  final double destinoLng;
  final String distancia;
  final String duracion;
  final String polyline;
  final DateTime fechaConsulta;
  final String? usuarioId;
  final String tipo; // 'usuario_a_tienda', 'tienda_a_usuario', 'otro'

  RutaModel({
    required this.id,
    required this.origenLat,
    required this.origenLng,
    required this.destinoLat,
    required this.destinoLng,
    required this.distancia,
    required this.duracion,
    required this.polyline,
    required this.fechaConsulta,
    this.usuarioId,
    required this.tipo,
  });

  factory RutaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return RutaModel(
      id: docId ?? map['id']?.toString() ?? '',
      origenLat: (map['origen_lat'] as num?)?.toDouble() ?? 0.0,
      origenLng: (map['origen_lng'] as num?)?.toDouble() ?? 0.0,
      destinoLat: (map['destino_lat'] as num?)?.toDouble() ?? 0.0,
      destinoLng: (map['destino_lng'] as num?)?.toDouble() ?? 0.0,
      distancia: map['distancia']?.toString() ?? '',
      duracion: map['duracion']?.toString() ?? '',
      polyline: map['polyline']?.toString() ?? '',
      fechaConsulta: map['fecha_consulta'] != null
          ? (map['fecha_consulta'] is Timestamp
              ? (map['fecha_consulta'] as Timestamp).toDate()
              : DateTime.tryParse(map['fecha_consulta'].toString()) ?? DateTime.now())
          : DateTime.now(),
      usuarioId: map['usuario_id']?.toString(),
      tipo: map['tipo']?.toString() ?? 'otro',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origen_lat': origenLat,
      'origen_lng': origenLng,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'distancia': distancia,
      'duracion': duracion,
      'polyline': polyline,
      'fecha_consulta': Timestamp.fromDate(fechaConsulta),
      'usuario_id': usuarioId,
      'tipo': tipo,
    };
  }
}
