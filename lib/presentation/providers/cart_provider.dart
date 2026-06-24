import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/cart_item.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final String? userId;

  CartNotifier(this.userId) : super([]) {
    if (userId != null) {
      loadCart();
    }
  }

  Future<void> loadCart() async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cart_$userId');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded.map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList();
        debugPrint('🛒 Carrito cargado para el usuario $userId: ${state.length} ítems');
      } else {
        state = [];
      }
    } catch (e) {
      debugPrint('❌ Error al cargar el carrito: $e');
    }
  }

  Future<void> _saveCart() async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((item) => item.toJson()).toList());
      await prefs.setString('cart_$userId', jsonStr);
      debugPrint('💾 Carrito guardado para el usuario $userId');
    } catch (e) {
      debugPrint('❌ Error al guardar el carrito: $e');
    }
  }

  /// Agrega un producto al carrito. Si ya existe, incrementa su cantidad.
  void addItem(CatalogoProducto producto, {int cantidad = 1}) {
    final index = state.indexWhere((item) => item.producto.id == producto.id);
    if (index != -1) {
      final existingItem = state[index];
      state = [
        ...state.sublist(0, index),
        existingItem.copyWith(cantidad: existingItem.cantidad + cantidad),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, CartItem(producto: producto, cantidad: cantidad)];
    }
    _saveCart();
  }

  /// Remueve un ítem del carrito completamente.
  void removeItem(String productoId) {
    state = state.where((item) => item.producto.id != productoId).toList();
    _saveCart();
  }

  /// Incrementa en 1 la cantidad de un producto.
  void incrementItem(String productoId) {
    state = state.map((item) {
      if (item.producto.id == productoId) {
        return item.copyWith(cantidad: item.cantidad + 1);
      }
      return item;
    }).toList();
    _saveCart();
  }

  /// Decrementa en 1 la cantidad de un producto. Si llega a 0, lo remueve.
  void decrementItem(String productoId) {
    state = state.map((item) {
      if (item.producto.id == productoId) {
        return item.copyWith(cantidad: item.cantidad - 1);
      }
      return item;
    }).where((item) => item.cantidad > 0).toList();
    _saveCart();
  }

  /// Modifica la cantidad de un producto directamente. Si es <= 0, lo remueve.
  void updateQuantity(String productoId, int cantidad) {
    if (cantidad <= 0) {
      removeItem(productoId);
    } else {
      state = state.map((item) {
        if (item.producto.id == productoId) {
          return item.copyWith(cantidad: cantidad);
        }
        return item;
      }).toList();
      _saveCart();
    }
  }

  /// Limpia todo el carrito.
  void clear() {
    state = [];
    _saveCart();
  }
}

// Provider global para interactuar con el carrito (dependiente del usuario)
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final user = ref.watch(authStateProvider);
  return CartNotifier(user?.id);
});

// Provider para la cantidad total de productos en el carrito (suma de cantidades)
final cartCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (total, item) => total + item.cantidad);
});

// Provider para el costo total unitario del carrito
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (total, item) => total + item.subtotal);
});

// Provider para el costo total mayorista del carrito
final cartTotalMayoristaProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (total, item) => total + item.subtotalMayorista);
});
