import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio de Firestore para Comercializadora Aly
/// Reemplaza ApiService (Render/NeonDB) como backend principal.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // PRODUCTOS (Inventario principal adaptado a catalogo_productos)
  // ============================================================
  Future<List<Map<String, dynamic>>> getProductos() async {
    final snapshot = await _db.collection('catalogo_productos').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
        'tipo_producto': data['categoria'] ?? '',
        'precio_referencia': data['precio_unitario'] ?? 0.0,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) async {
    final dataAdaptada = {
      ...data,
      'categoria': data['tipo_producto'] ?? 'Otros',
      'subcategoria': data['subcategoria'] ?? 'General',
      'marca': data['marca'] ?? 'Sin marca',
      'unidad': data['unidad'] ?? 'unidad',
      'stock_minimo': data['stock_minimo'] ?? 5,
      'precio_unitario': data['precio_referencia'] ?? 0.0,
      'precio_mayorista': data['precio_mayorista'] ?? (data['precio_referencia'] ?? 0.0) * 0.8,
      'disponible': data['disponible'] ?? true,
      'tags': data['tags'] ?? [],
      'caracteristicas': data['caracteristicas'] ?? [],
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
    final ref = await _db.collection('catalogo_productos').add(dataAdaptada);
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> updateProducto(String id, Map<String, dynamic> data) async {
    final dataAdaptada = {
      ...data,
      if (data.containsKey('tipo_producto')) 'categoria': data['tipo_producto'],
      if (data.containsKey('precio_referencia')) 'precio_unitario': data['precio_referencia'],
    };
    await _db.collection('catalogo_productos').doc(id).update(dataAdaptada);
    return {'id': id, ...data};
  }

  Future<void> deleteProducto(String id) async {
    await _db.collection('catalogo_productos').doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> productosStream() {
    return _db.collection('catalogo_productos').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'tipo_producto': data['categoria'] ?? '',
          'precio_referencia': data['precio_unitario'] ?? 0.0,
        };
      }).toList(),
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

  Future<void> registrarMovimiento({
    required String productoId,
    required String nombreProducto,
    required String tipoOperacion,
    String? detalles,
  }) async {
    try {
      await _db.collection('inventario_movimientos').add({
        'producto_id': productoId,
        'nombre_producto': nombreProducto,
        'tipo_operacion': tipoOperacion,
        'detalles': detalles ?? '',
        'fecha': FieldValue.serverTimestamp(),
        'usuario': 'operador_aly@comercializadoraaly.com',
      });
      debugPrint('📝 Auditoría: Registrado movimiento de inventario ($tipoOperacion) para $nombreProducto');
    } catch (e) {
      debugPrint('⚠️ Auditoría: Error al registrar movimiento: $e');
    }
  }

  Future<Map<String, dynamic>> createCatalogoProducto(Map<String, dynamic> data) async {
    final ref = await _db.collection('catalogo_productos').add({
      ...data,
      'fecha_creacion': FieldValue.serverTimestamp(),
    });
    await registrarMovimiento(
      productoId: ref.id,
      nombreProducto: data['nombre'] ?? 'Nuevo Producto',
      tipoOperacion: 'CREAR',
      detalles: 'Creado con precio unitario S/ ${data['precio_unitario']}',
    );
    return {'id': ref.id, ...data};
  }

  Future<Map<String, dynamic>> updateCatalogoProducto(String id, Map<String, dynamic> data) async {
    await _db.collection('catalogo_productos').doc(id).update(data);
    await registrarMovimiento(
      productoId: id,
      nombreProducto: data['nombre'] ?? 'Producto Modificado',
      tipoOperacion: 'MODIFICAR',
      detalles: 'Campos actualizados: ${data.keys.join(", ")}',
    );
    return {'id': id, ...data};
  }

  Future<void> deleteCatalogoProducto(String id) async {
    try {
      final doc = await _db.collection('catalogo_productos').doc(id).get();
      final nombre = doc.data()?['nombre'] ?? 'Producto Desconocido';
      await _db.collection('catalogo_productos').doc(id).delete();
      await registrarMovimiento(
        productoId: id,
        nombreProducto: nombre,
        tipoOperacion: 'ELIMINAR',
        detalles: 'Producto eliminado del catálogo.',
      );
    } catch (e) {
      await _db.collection('catalogo_productos').doc(id).delete();
    }
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
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return [];
    
    // Obtener rol del usuario actual
    final userDoc = await _db.collection('users').doc(fbUser.uid).get();
    final role = userDoc.data()?['rol'] ?? 'comprador';
    
    QuerySnapshot<Map<String, dynamic>> snapshot;
    if (role == 'comprador') {
      snapshot = await _db.collection('pedidos')
          .where('comprador_id', isEqualTo: fbUser.uid)
          .get();
    } else {
      snapshot = await _db.collection('pedidos').get();
    }
    
    final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    // Ordenar en memoria por fecha_pedido descendente para evitar indexación compleja en Firebase
    list.sort((a, b) {
      final aFecha = a['fecha_pedido'] ?? '';
      final bFecha = b['fecha_pedido'] ?? '';
      return bFecha.compareTo(aFecha);
    });
    
    return list;
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
    debugPrint('🗑️ Seeder: Limpiando colección antigua "productos" y "catalogo_productos"...');
    
    // Limpiar colección antigua de productos (si hay permisos)
    try {
      final productosSnapshot = await _db.collection('productos').get();
      final batchProd = _db.batch();
      for (final doc in productosSnapshot.docs) {
        batchProd.delete(doc.reference);
      }
      await batchProd.commit();
    } catch (e) {
      debugPrint('ℹ️ Seeder: No se pudo limpiar la colección "productos" (seguramente por falta de permisos/autenticación). Continuando...');
    }

    // Limpiar catalogo_productos
    final catalogoSnapshot = await _db.collection('catalogo_productos').get();
    final batchCat = _db.batch();
    for (final doc in catalogoSnapshot.docs) {
      batchCat.delete(doc.reference);
    }
    await batchCat.commit();

    debugPrint('🌱 Seeder: Cargando 45 productos del catálogo en Firestore...');
    final batchInsert = _db.batch();
    int count = 0;

    for (final producto in productos) {
      final ref = _db.collection('catalogo_productos').doc();
      batchInsert.set(ref, {
        ...producto,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      count++;
    }

    await batchInsert.commit();
    debugPrint('✅ Seeder: $count productos del catálogo insertados de forma limpia en Firestore');
    return count;
  }

  /// Verifica si el catálogo ya fue poblado con los 45 productos exactos
  Future<bool> isCatalogoSeeded() async {
    final snapshot = await _db.collection('catalogo_productos').get();
    return snapshot.docs.length == 45;
  }

  /// Limpia todos los productos del catálogo en Firestore
  Future<void> clearCatalogoProductos() async {
    debugPrint('🗑️ Firestore: Limpiando colección catalogo_productos...');
    final snapshot = await _db.collection('catalogo_productos').get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    debugPrint('🗑️ Firestore: Colección catalogo_productos vaciada con éxito.');
  }
}
