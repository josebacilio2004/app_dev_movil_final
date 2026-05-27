/// Utilidades de búsqueda inteligente para Comercializadora Aly
/// Soporta normalización de acentos, fuzzy matching y ranking por relevancia.
library;

class SearchUtils {
  /// Mapa de caracteres acentuados a sus equivalentes sin acento
  static const Map<String, String> _acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
    'ñ': 'n', 'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o',
    'Ú': 'u', 'Ñ': 'n',
  };

  /// Normaliza texto para búsqueda: minúsculas, sin acentos, sin espacios extra
  static String normalizeText(String text) {
    String result = text.toLowerCase().trim();
    _acentos.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    // Remover caracteres especiales excepto espacios y guiones
    result = result.replaceAll(RegExp(r'[^\w\s-]'), '');
    // Comprimir espacios múltiples
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result;
  }

  /// Calcula una puntuación de coincidencia fuzzy entre query y text
  /// Retorna un valor entre 0.0 (sin coincidencia) y 1.0 (coincidencia exacta)
  static double fuzzyMatch(String query, String text) {
    final q = normalizeText(query);
    final t = normalizeText(text);

    if (q.isEmpty || t.isEmpty) return 0.0;
    if (t == q) return 1.0;
    if (t.startsWith(q)) return 0.9;
    if (t.contains(q)) return 0.7;

    // Búsqueda por palabras individuales
    final queryWords = q.split(' ').where((w) => w.length > 1).toList();
    if (queryWords.isEmpty) return 0.0;

    int matches = 0;
    for (final word in queryWords) {
      if (t.contains(word)) matches++;
    }

    return matches / queryWords.length * 0.6;
  }

  /// Busca en una lista de campos y retorna la puntuación máxima
  static double searchScore(String query, List<String> fields) {
    double maxScore = 0;
    for (final field in fields) {
      final score = fuzzyMatch(query, field);
      if (score > maxScore) maxScore = score;
    }
    return maxScore;
  }

  /// Búsqueda inteligente en productos con ranking
  /// Busca en nombre, marca, categoría, descripción y tags
  static List<T> searchAndRank<T>({
    required String query,
    required List<T> items,
    required List<String> Function(T item) getSearchFields,
    double minScore = 0.1,
  }) {
    if (query.trim().isEmpty) return items;

    final scored = <MapEntry<T, double>>[];

    for (final item in items) {
      final fields = getSearchFields(item);
      final score = searchScore(query, fields);
      if (score >= minScore) {
        scored.add(MapEntry(item, score));
      }
    }

    // Ordenar por puntuación descendente
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Genera sugerencias de búsqueda basadas en los campos disponibles
  static List<String> generateSuggestions({
    required String query,
    required List<String> allTerms,
    int maxSuggestions = 5,
  }) {
    if (query.isEmpty) return [];

    final q = normalizeText(query);
    final suggestions = <MapEntry<String, double>>[];

    for (final term in allTerms) {
      final score = fuzzyMatch(q, term);
      if (score > 0.3) {
        suggestions.add(MapEntry(term, score));
      }
    }

    suggestions.sort((a, b) => b.value.compareTo(a.value));
    return suggestions.take(maxSuggestions).map((e) => e.key).toList();
  }

  /// Resalta las coincidencias en un texto para mostrar en UI
  /// Retorna una lista de segmentos {text, isMatch}
  static List<Map<String, dynamic>> highlightMatches(String query, String text) {
    if (query.isEmpty) return [{'text': text, 'isMatch': false}];

    final q = normalizeText(query);
    final tNorm = normalizeText(text);
    final segments = <Map<String, dynamic>>[];

    int lastIndex = 0;
    int index = tNorm.indexOf(q);

    while (index != -1 && lastIndex < text.length) {
      if (index > lastIndex) {
        segments.add({'text': text.substring(lastIndex, index), 'isMatch': false});
      }
      segments.add({'text': text.substring(index, index + query.length), 'isMatch': true});
      lastIndex = index + query.length;
      index = tNorm.indexOf(q, lastIndex);
    }

    if (lastIndex < text.length) {
      segments.add({'text': text.substring(lastIndex), 'isMatch': false});
    }

    return segments.isEmpty ? [{'text': text, 'isMatch': false}] : segments;
  }
}
