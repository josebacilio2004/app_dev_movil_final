import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/firestore_service.dart';

/// ADAPTADOR API A FIREBASE FIRESTORE — Comercializadora Aly
/// Este servicio mantiene la firma y métodos de ApiService para no romper
/// la UI y providers existentes, pero redirige todo el tráfico a Firestore.
class ApiService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // MÉTODOS DE PETICIÓN REST (Simulados para Firebase)
  // ============================================================
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    debugPrint('🌐 ApiService.get (Firebase Adaptado): $path');
    dynamic data;

    try {
      if (path == '/tanda-notas') {
        data = await _firestore.getNotas();
      } else if (path == '/pedidos') {
        data = await _firestore.getPedidos();
      } else if (path == '/facturas-comprador') {
        data = await _firestore.getFacturas();
      } else if (path.startsWith('/facturas-comprador/')) {
        // e.g. /facturas-comprador/compradorId
        final parts = path.split('/');
        final id = parts.last;
        data = await _firestore.getFacturasComprador(id);
      } else {
        debugPrint('⚠️ Path GET no mapeado: $path');
        data = [];
      }

      return Response(
        requestOptions: RequestOptions(path: path),
        data: data,
        statusCode: 200,
      );
    } catch (e) {
      debugPrint('❌ Error ApiService.get: $e');
      return Response(
        requestOptions: RequestOptions(path: path),
        data: [],
        statusCode: 500,
        statusMessage: e.toString(),
      );
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    debugPrint('🌐 ApiService.post (Firebase Adaptado): $path');
    dynamic result;

    try {
      if (path == '/tandas') {
        final ref = await _db.collection('tandas').add({
          ...?data,
          'fecha_inicio': FieldValue.serverTimestamp(),
        });
        result = {'id': ref.id, ...?data};
      } else if (path == '/pedidos-herramientas') {
        result = await _firestore.createPedido(data as Map<String, dynamic>);
      } else if (path == '/tanda-notas') {
        final ref = await _db.collection('tanda_notas').add({
          ...?data,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
        result = {'id': ref.id, ...?data};
      } else {
        debugPrint('⚠️ Path POST no mapeado: $path');
        result = {};
      }

      return Response(
        requestOptions: RequestOptions(path: path),
        data: result,
        statusCode: 200,
      );
    } catch (e) {
      debugPrint('❌ Error ApiService.post: $e');
      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        statusMessage: e.toString(),
      );
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    debugPrint('🌐 ApiService.put (Firebase Adaptado): $path');

    try {
      if (path.startsWith('/tandas/')) {
        final parts = path.split('/');
        final id = parts.last;
        await _db.collection('tandas').doc(id).update(data as Map<String, dynamic>);
      } else {
        debugPrint('⚠️ Path PUT no mapeado: $path');
      }

      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
    } catch (e) {
      debugPrint('❌ Error ApiService.put: $e');
      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        statusMessage: e.toString(),
      );
    }
  }

  Future<Response> delete(String path) async {
    debugPrint('🌐 ApiService.delete (Firebase Adaptado): $path');
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  // ============================================================
  // SERVICIOS ESPECÍFICOS (Simulados sobre Firestore)
  // ============================================================

  // --- LOGIN (DEPRECADO, se mantiene por compatibilidad) ---
  Future<Map<String, dynamic>> login(String role, String identifier, String password) async {
    debugPrint('⚠️ login() invocado en ApiService adapter');
    throw UnimplementedError('Usar AuthService para autenticación de Firebase');
  }

  // --- PRODUCTOS ---
  Future<List<Map<String, dynamic>>> getProductos() => _firestore.getProductos();
  Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) => _firestore.createProducto(data);
  Future<Map<String, dynamic>> updateProducto(dynamic id, Map<String, dynamic> data) => _firestore.updateProducto(id.toString(), data);
  Future<void> deleteProducto(dynamic id) => _firestore.deleteProducto(id.toString());

  // --- DISTRIBUIDORES ---
  Future<List<Map<String, dynamic>>> getDistribuidores() => _firestore.getDistribuidores();
  Future<Map<String, dynamic>> createDistribuidor(Map<String, dynamic> data) => _firestore.createDistribuidor(data);
  Future<Map<String, dynamic>> updateDistribuidor(dynamic id, Map<String, dynamic> data) => _firestore.updateDistribuidor(id.toString(), data);
  Future<void> deleteDistribuidor(dynamic id) => _firestore.deleteDistribuidor(id.toString());

  // --- PEDIDOS ---
  Future<List<Map<String, dynamic>>> getPedidos() => _firestore.getPedidos();
  Future<Map<String, dynamic>> createPedido(Map<String, dynamic> data) => _firestore.createPedido(data);
  Future<Map<String, dynamic>> updatePedido(dynamic id, Map<String, dynamic> data) => _firestore.updatePedido(id.toString(), data);
  Future<void> deletePedido(dynamic id) => _firestore.deletePedido(id.toString());

  // --- TANDAS ---
  Future<List<Map<String, dynamic>>> getTandas() => _firestore.getTandas();

  // --- COMPRADORES ---
  Future<List<Map<String, dynamic>>> getCompradores() => _firestore.getCompradores();
  Future<Map<String, dynamic>> updateComprador(dynamic id, Map<String, dynamic> data) => _firestore.updateComprador(id.toString(), data);

  // --- INVERSIONISTAS ---
  Future<List<Map<String, dynamic>>> getInversionistas() => _firestore.getInversionistas();
  Future<Map<String, dynamic>> updateInversionista(dynamic id, Map<String, dynamic> data) => _firestore.updateInversionista(id.toString(), data);

  // --- FACTURAS Y ABONOS ---
  Future<List<Map<String, dynamic>>> getFacturasComprador(dynamic compradorId, {dynamic distribuidorId}) =>
      _firestore.getFacturasComprador(compradorId.toString(), distribuidorId: distribuidorId?.toString());
  Future<Map<String, dynamic>> createAbono(dynamic facturaId, Map<String, dynamic> data) => _firestore.createAbono(facturaId.toString(), data);
  Future<List<Map<String, dynamic>>> getAbonosFactura(dynamic facturaId) => _firestore.getAbonosFactura(facturaId.toString());

  // --- MAYORISTAS ---
  Future<List<Map<String, dynamic>>> getMayoristasClientes() => _firestore.getMayoristasClientes();
  Future<Map<String, dynamic>> createMayoristaCliente(Map<String, dynamic> data) => _firestore.createMayoristaCliente(data);
  Future<List<Map<String, dynamic>>> getMayoristaStock() => _firestore.getMayoristaStock();
  Future<List<Map<String, dynamic>>> getMayoristaVentas() => _firestore.getMayoristaVentas();
  Future<Map<String, dynamic>> createMayoristaVenta(Map<String, dynamic> data) => _firestore.createMayoristaVenta(data);
  Future<Map<String, dynamic>> createStockManual(Map<String, dynamic> data) => _firestore.createStockManual(data);
}
