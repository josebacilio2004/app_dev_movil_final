import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/api_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/producto.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/tanda.dart';

// --- PROVEEDOR DE SERVICIO API ---
final apiServiceProvider = Provider((ref) => ApiService());

// --- PROVIDERS PARA PRODUCTOS ---
final productsFutureProvider = FutureProvider<List<Producto>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getProductos();
  return data.map((e) => Producto.fromJson(e)).toList();
});

// --- PROVIDERS PARA DISTRIBUIDORES ---
final distributorsFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getDistribuidores();
});

// --- PROVIDERS PARA TANDAS ---
final tandasFutureProvider = FutureProvider<List<Tanda>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getTandas();
  return data.map((e) => Tanda.fromJson(e)).toList();
});

// --- PROVIDERS PARA NOTAS ---
final notesFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  // Intentamos obtener notas de la tanda activa si es posible o todas
  final response = await api.get('/tanda-notas');
  return List<Map<String, dynamic>>.from(response.data);
});

// --- PROVIDERS PARA COMPRADORES (Stats) ---
final buyersFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getCompradores();
});

// --- PROVIDERS PARA INVERSIONISTAS (Stats) ---
final investorsFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getInversionistas();
});

// --- PROVIDER PARA PEDIDOS (Inversionista) ---
final ordersFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/pedidos');
  return List<Map<String, dynamic>>.from(response.data);
});

// --- PROVIDER PARA FACTURAS ---
final invoicesFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/facturas-comprador');
  return List<Map<String, dynamic>>.from(response.data);
});

// Mapeos de compatibilidad para evitar romper UI existente temporalmente
final productsStreamProvider = productsFutureProvider;
final ordersStreamProvider = ordersFutureProvider;
final tandasStreamProvider = tandasFutureProvider;
final invoicesStreamProvider = invoicesFutureProvider;
final notesStreamProvider = notesFutureProvider;
final investorsStreamProvider = investorsFutureProvider;
final buyersStreamProvider = buyersFutureProvider;
