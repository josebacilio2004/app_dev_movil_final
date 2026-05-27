class Usuario {
  final String id;
  final String nombre;
  final String usuario;
  final String rol;
  final String? email;

  Usuario({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    this.email,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id']?.toString() ?? json['uid']?.toString() ?? '',
      nombre: json['nombre'] ?? 'Sin Nombre',
      usuario: json['usuario'] ?? '',
      rol: json['rol'] ?? 'usuario',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'usuario': usuario,
      'rol': rol,
      'email': email,
    };
  }
}
