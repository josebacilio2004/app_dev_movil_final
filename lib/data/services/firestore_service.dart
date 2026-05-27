import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio de Firestore para Comercializadora Aly
/// Reemplaza ApiService (Render/NeonDB) como backend principal.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // PRODUCTOS (Inventario principal)
  // ============================================================
  Future<List<Map<String, dynamic>>> getProductos() async {
    final snapshot = await _db.collection('productos').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) async {
    final ref = await _db.collection('productos').add({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> updateProducto(String id, Map<String, dynamic> data) async {
    await _db.collection('productos').doc(id).update(data);
    return {'id': id, ...data};
  }

  Future<void> deleteProducto(String id) async {
    await _db.collection('productos').doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> productosStream() {
    return _db.collection('productos').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ============================================================
  // CATÁLOGO DE PRODUCTOS
  // ============================================================
  Future<List<Map<String, dynamic>>> getCatalogoProductos() async {
    final snapshot = await _db.collection('catalogo_productos')
        .where('disponible', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> catalogoProductosStream() {
    return _db.collection('catalogo_productos')
        .orderBy('categoria')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<Map<String, dynamic>> createCatalogoProducto(Map<String, dynamic> data) async {
    final ref = await _db.collection('catalogo_productos').add({
      ...data,
      'fecha_creacion': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  // ============================================================
  // DISTRIBUIDORES
  // ============================================================
  Future<List<Map<String, dynamic>>> getDistribuidores() async {
    final snapshot = await _db.collection('distribuidores').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createDistribuidor(Map<String, dynamic> data) async {
    final ref = await _db.collection('distribuidores').add({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> updateDistribuidor(String id, Map<String, dynamic> data) async {
    await _db.collection('distribuidores').doc(id).update(data);
    return {'id': id, ...data};
  }

  Future<void> deleteDistribuidor(String id) async {
    await _db.collection('distribuidores').doc(id).delete();
  }

  // ============================================================
  // PEDIDOS (Compras / Inversiones)
  // ============================================================
  Future<List<Map<String, dynamic>>> getPedidos() async {
    final snapshot = await _db.collection('pedidos').orderBy('fecha_pedido', descending: true).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createPedido(Map<String, dynamic> data) async {
    final ref = await _db.collection('pedidos').add({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> updatePedido(String id, Map<String, dynamic> data) async {
    await _db.collection('pedidos').doc(id).update(data);
    return {'id': id, ...data};
  }

  Future<void> deletePedido(String id) async {
    await _db.collection('pedidos').doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> pedidosStream() {
    return _db.collection('pedidos').orderBy('fecha_pedido', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ============================================================
  // TANDAS
  // ============================================================
  Future<List<Map<String, dynamic>>> getTandas() async {
    final snapshot = await _db.collection('tandas').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> tandasStream() {
    return _db.collection('tandas').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ============================================================
  // COMPRADORES
  // ============================================================
  Future<List<Map<String, dynamic>>> getCompradores() async {
    final snapshot = await _db.collection('compradores').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> updateComprador(String id, Map<String, dynamic> data) async {
    await _db.collection('compradores').doc(id).update(data);
    return {'id': id, ...data};
  }

  // ============================================================
  // INVERSIONISTAS
  // ============================================================
  Future<List<Map<String, dynamic>>> getInversionistas() async {
    final snapshot = await _db.collection('inversionistas').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> updateInversionista(String id, Map<String, dynamic> data) async {
    await _db.collection('inversionistas').doc(id).update(data);
    return {'id': id, ...data};
  }

  // ============================================================
  // FACTURAS Y ABONOS (Compradores)
  // ============================================================
  Future<List<Map<String, dynamic>>> getFacturasComprador(String compradorId, {String? distribuidorId}) async {
    Query<Map<String, dynamic>> query = _db.collection('facturas_comprador').where('comprador_id', isEqualTo: compradorId);
    if (distribuidorId != null) {
      query = query.where('distribuidor_id', isEqualTo: distribuidorId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createAbono(String facturaId, Map<String, dynamic> data) async {
    final ref = await _db.collection('facturas_comprador').doc(facturaId).collection('abonos').add({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  Future<List<Map<String, dynamic>>> getAbonosFactura(String facturaId) async {
    final snapshot = await _db.collection('facturas_comprador').doc(facturaId).collection('abonos').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // ============================================================
  // MAYORISTAS
  // ============================================================
  Future<List<Map<String, dynamic>>> getMayoristasClientes() async {
    final snapshot = await _db.collection('mayoristas_clientes').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createMayoristaCliente(Map<String, dynamic> data) async {
    final ref = await _db.collection('mayoristas_clientes').add(data);
    return {'id': ref.id, ...data};
  }

  Future<List<Map<String, dynamic>>> getMayoristaStock() async {
    final snapshot = await _db.collection('mayorista_stock').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getMayoristaVentas() async {
    final snapshot = await _db.collection('mayorista_ventas').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> createMayoristaVenta(Map<String, dynamic> data) async {
    final ref = await _db.collection('mayorista_ventas').add({
      ...data,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> createStockManual(Map<String, dynamic> data) async {
    final ref = await _db.collection('mayorista_stock').add(data);
    return {'id': ref.id, ...data};
  }

  // ============================================================
  // NOTAS (Tanda Notas)
  // ============================================================
  Future<List<Map<String, dynamic>>> getNotas() async {
    final snapshot = await _db.collection('tanda_notas').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> notasStream() {
    return _db.collection('tanda_notas').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ============================================================
  // USERS (para gestión de roles)
  // ============================================================
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return {'id': doc.id, ...doc.data()!};
    }
    return null;
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data);
  }

  // ============================================================
  // FACTURAS (General)
  // ============================================================
  Future<List<Map<String, dynamic>>> getFacturas() async {
    final snapshot = await _db.collection('facturas_comprador').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> facturasStream() {
    return _db.collection('facturas_comprador').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ============================================================
  // SEEDER — Ejecutar escritura masiva con batch
  // ============================================================
  Future<int> seedCatalogoProductos(List<Map<String, dynamic>> productos) async {
    final batch = _db.batch();
    int count = 0;

    for (final producto in productos) {
      final ref = _db.collection('catalogo_productos').doc();
      batch.set(ref, {
        ...producto,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      count++;
    }

    await batch.commit();
    debugPrint('✅ Seeder: $count productos del catálogo insertados en Firestore');
    return count;
  }

  /// Verifica si el catálogo ya fue poblado
  Future<bool> isCatalogoSeeded() async {
    final snapshot = await _db.collection('catalogo_productos').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
}
