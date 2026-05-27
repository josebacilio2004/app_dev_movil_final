class MayoristaCliente {
  final String id;
  final String nombre;
  final String? documento;
  final String? telefono;
  final String? direccion;
  final bool activo;

  MayoristaCliente({
    required this.id,
    required this.nombre,
    this.documento,
    this.telefono,
    this.direccion,
    this.activo = true,
  });

  factory MayoristaCliente.fromJson(Map<String, dynamic> json) {
    return MayoristaCliente(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      documento: json['documento'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'documento': documento,
      'telefono': telefono,
      'direccion': direccion,
      'activo': activo,
    };
  }
}
