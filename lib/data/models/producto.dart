class Producto {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipoProducto;
  final double precioReferencia;
  final String? imagenUrl;
  final String? distribuidorId;
  final String? distribuidorNombre;

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipoProducto,
    required this.precioReferencia,
    this.imagenUrl,
    this.distribuidorId,
    this.distribuidorNombre,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      tipoProducto: json['tipo_producto'] ?? '',
      precioReferencia: _parseDouble(json['precio_referencia']),
      imagenUrl: json['imagen_url'],
      distribuidorId: json['distribuidor_id']?.toString(),
      distribuidorNombre: json['distribuidor_nombre'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo_producto': tipoProducto,
      'precio_referencia': precioReferencia,
      'imagen_url': imagenUrl,
      'distribuidor_id': distribuidorId,
    };
  }
}
