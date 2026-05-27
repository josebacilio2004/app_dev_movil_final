class DniResultado {
  final String numero;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombreCompleto;

  DniResultado({
    required this.numero,
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.nombreCompleto,
  });

  factory DniResultado.fromJson(Map<String, dynamic> json) {
    // La API de APIs Perú devuelve los campos en la raíz o en una clave 'data' dependiendo del endpoint.
    // Manejaremos ambos formatos de manera robusta.
    final data = json.containsKey('data') ? json['data'] as Map<String, dynamic> : json;

    final numero = data['numero']?.toString() ?? data['numeroDocumento']?.toString() ?? '';
    final nombres = data['nombres']?.toString() ?? '';
    final paterno = data['apellidoPaterno']?.toString() ?? data['apellido_paterno']?.toString() ?? '';
    final materno = data['apellidoMaterno']?.toString() ?? data['apellido_materno']?.toString() ?? '';
    
    // Si no viene nombreCompleto, lo construimos
    final completo = data['nombreCompleto']?.toString() ?? 
                     data['nombre_completo']?.toString() ?? 
                     '$nombres $paterno $materno'.trim().replaceAll(RegExp(r'\s+'), ' ');

    return DniResultado(
      numero: numero,
      nombres: nombres,
      apellidoPaterno: paterno,
      apellidoMaterno: materno,
      nombreCompleto: completo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'nombres': nombres,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'nombre_completo': nombreCompleto,
    };
  }

  @override
  String toString() => nombreCompleto;
}
