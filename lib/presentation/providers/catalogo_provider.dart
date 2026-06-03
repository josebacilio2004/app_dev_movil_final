import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/firestore_service.dart';
import 'package:gestor_invetarios_pedidos_app/core/utils/search_utils.dart';

// --- Provider del servicio Firestore ---
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// --- Stream de catálogo desde Firestore ---
final catalogoStreamProvider = StreamProvider<List<CatalogoProducto>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.catalogoProductosStream().map(
    (list) => list.map((e) => CatalogoProducto.fromJson(e, docId: e['id'])).toList(),
  );
});

// --- Estado de la búsqueda ---
final searchQueryProvider = StateProvider<String>((ref) => '');

// --- Filtro de categoría ---
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// --- Rango de precios ---
final precioMinProvider = StateProvider<double>((ref) => 0);
final precioMaxProvider = StateProvider<double>((ref) => 999999);

// --- Solo disponibles ---
final soloDisponiblesProvider = StateProvider<bool>((ref) => false);

// --- Categorías disponibles (extraídas del catálogo) ---
final categoriasProvider = Provider<List<String>>((ref) {
  final catalogoAsync = ref.watch(catalogoStreamProvider);
  return catalogoAsync.when(
    data: (productos) {
      final categorias = productos.map((p) => p.categoria).toSet().toList();
      categorias.sort();
      return categorias;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// --- Marcas disponibles ---
final marcasProvider = Provider<List<String>>((ref) {
  final catalogoAsync = ref.watch(catalogoStreamProvider);
  return catalogoAsync.when(
    data: (productos) {
      final marcas = productos.map((p) => p.marca).toSet().toList();
      marcas.sort();
      return marcas;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// --- Filtro de marca ---
final selectedBrandProvider = StateProvider<String?>((ref) => null);

// --- RESULTADOS DE BÚSQUEDA INTELIGENTE ---
final searchResultsProvider = Provider<List<CatalogoProducto>>((ref) {
  final catalogoAsync = ref.watch(catalogoStreamProvider);
  final query = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedBrand = ref.watch(selectedBrandProvider);
  final soloDisponibles = ref.watch(soloDisponiblesProvider);
  final precioMin = ref.watch(precioMinProvider);
  final precioMax = ref.watch(precioMaxProvider);

  return catalogoAsync.when(
    data: (productos) {
      // Paso 1: Filtrar por categoría si está seleccionada
      var filtered = productos.toList();
      
      if (selectedCategory != null && selectedCategory.isNotEmpty) {
        filtered = filtered.where((p) => p.categoria == selectedCategory).toList();
      }

      // Paso 1.5: Filtrar por marca si está seleccionada
      if (selectedBrand != null && selectedBrand.isNotEmpty) {
        filtered = filtered.where((p) => p.marca == selectedBrand).toList();
      }

      // Paso 2: Filtrar por disponibilidad
      if (soloDisponibles) {
        filtered = filtered.where((p) => p.disponible).toList();
      }

      // Paso 3: Filtrar por rango de precio
      filtered = filtered.where((p) => 
        p.precioUnitario >= precioMin && p.precioUnitario <= precioMax
      ).toList();

      // Paso 4: Búsqueda inteligente con ranking
      if (query.trim().isNotEmpty) {
        filtered = SearchUtils.searchAndRank<CatalogoProducto>(
          query: query,
          items: filtered,
          getSearchFields: (p) => [
            p.nombre,
            p.marca,
            p.categoria,
            p.subcategoria,
            p.descripcion,
            ...p.tags,
            p.codigoSku ?? '',
          ],
          minScore: 0.1,
        );
      }

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// --- Contador de resultados ---
final searchResultCountProvider = Provider<int>((ref) {
  return ref.watch(searchResultsProvider).length;
});

// --- Total de productos en catálogo ---
final totalCatalogoProvider = Provider<int>((ref) {
  final catalogoAsync = ref.watch(catalogoStreamProvider);
  return catalogoAsync.when(
    data: (productos) => productos.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
