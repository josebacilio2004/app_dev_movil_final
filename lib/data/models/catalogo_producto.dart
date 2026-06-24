import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogoProducto {
  final String id;
  final String nombre;
  final String descripcion;
  final String categoria;
  final String subcategoria;
  final double precioUnitario;
  final double precioMayorista;
  final String unidad;
  final String? imagenUrl;
  final String marca;
  final bool disponible;
  final int stockMinimo;
  final List<String> tags;
  final List<String> caracteristicas;
  final String? codigoSku;
  final DateTime? fechaCreacion;

  CatalogoProducto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.subcategoria,
    required this.precioUnitario,
    required this.precioMayorista,
    required this.unidad,
    this.imagenUrl,
    required this.marca,
    this.disponible = true,
    this.stockMinimo = 5,
    this.tags = const [],
    this.caracteristicas = const [],
    this.codigoSku,
    this.fechaCreacion,
  });

  factory CatalogoProducto.fromJson(Map<String, dynamic> json, {String? docId}) {
    return CatalogoProducto(
      id: docId ?? json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      categoria: json['categoria'] ?? '',
      subcategoria: json['subcategoria'] ?? '',
      precioUnitario: _parseDouble(json['precio_unitario']),
      precioMayorista: _parseDouble(json['precio_mayorista']),
      unidad: json['unidad'] ?? 'unidad',
      imagenUrl: json['imagen_url'],
      marca: json['marca'] ?? '',
      disponible: json['disponible'] ?? true,
      stockMinimo: json['stock_minimo'] ?? 5,
      tags: List<String>.from(json['tags'] ?? []),
      caracteristicas: List<String>.from(json['caracteristicas'] ?? []),
      codigoSku: json['codigo_sku'],
      fechaCreacion: json['fecha_creacion'] != null
          ? (json['fecha_creacion'] is Timestamp
              ? (json['fecha_creacion'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_creacion'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'precio_unitario': precioUnitario,
      'precio_mayorista': precioMayorista,
      'unidad': unidad,
      'imagen_url': imagenUrl,
      'marca': marca,
      'disponible': disponible,
      'stock_minimo': stockMinimo,
      'tags': tags,
      'caracteristicas': caracteristicas,
      'codigo_sku': codigoSku,
      'fecha_creacion': fechaCreacion?.toIso8601String() ?? DateTime.now().toIso8601String(),
      // Campo auxiliar para búsqueda: nombre en minúsculas sin acentos
      'nombre_busqueda': _normalizarTexto(nombre),
      'marca_busqueda': _normalizarTexto(marca),
      'categoria_busqueda': _normalizarTexto(categoria),
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _normalizarTexto(String texto) {
    String normalizado = texto.toLowerCase().trim();
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
      'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
      'ñ': 'n',
    };
    acentos.forEach((key, value) {
      normalizado = normalizado.replaceAll(key, value);
    });
    return normalizado;
  }

  /// Genera una puntuación de relevancia para una búsqueda
  double relevanciaParaBusqueda(String query) {
    final q = _normalizarTexto(query);
    double score = 0;

    final nombreNorm = _normalizarTexto(nombre);
    final marcaNorm = _normalizarTexto(marca);
    final categoriaNorm = _normalizarTexto(categoria);
    final descripcionNorm = _normalizarTexto(descripcion);

    // Coincidencia exacta en nombre = máxima prioridad
    if (nombreNorm == q) return 100;
    // Nombre empieza con la query
    if (nombreNorm.startsWith(q)) score += 80;
    // Nombre contiene la query
    else if (nombreNorm.contains(q)) score += 60;

    // Marca coincide
    if (marcaNorm.contains(q)) score += 40;
    // Categoría coincide
    if (categoriaNorm.contains(q)) score += 30;
    // Descripción contiene
    if (descripcionNorm.contains(q)) score += 20;

    // Tags coinciden
    for (final tag in tags) {
      if (_normalizarTexto(tag).contains(q)) {
        score += 25;
        break;
      }
    }

    // Búsqueda por palabras individuales
    final palabras = q.split(' ').where((p) => p.length > 1).toList();
    if (palabras.length > 1) {
      int matches = 0;
      for (final palabra in palabras) {
        if (nombreNorm.contains(palabra) ||
            marcaNorm.contains(palabra) ||
            categoriaNorm.contains(palabra) ||
            descripcionNorm.contains(palabra)) {
          matches++;
        }
      }
      score += (matches / palabras.length) * 50;
    }

    return score;
  }
}
