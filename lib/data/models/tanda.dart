class Tanda {
  final String id;
  final String nombre;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String estado;
  final String? operadorId;
  final double? picos;
  final double? zapapicos;

  Tanda({
    required this.id,
    required this.nombre,
    required this.fechaInicio,
    this.fechaFin,
    required this.estado,
    this.operadorId,
    this.picos,
    this.zapapicos,
  });

  factory Tanda.fromJson(Map<String, dynamic> json) {
    return Tanda(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      fechaInicio: DateTime.parse(json['fecha_inicio'] ?? DateTime.now().toIso8601String()),
      fechaFin: json['fecha_fin'] != null ? DateTime.parse(json['fecha_fin']) : null,
      estado: json['estado'] ?? 'activa',
      operadorId: json['operador_id']?.toString(),
      picos: _parseDouble(json['picos']),
      zapapicos: _parseDouble(json['zapapicos']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
