import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';

class CartItem {
  final CatalogoProducto producto;
  final int cantidad;

  CartItem({
    required this.producto,
    required this.cantidad,
  });

  CartItem copyWith({
    CatalogoProducto? producto,
    int? cantidad,
  }) {
    return CartItem(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  double get subtotal => producto.precioUnitario * cantidad;
  double get subtotalMayorista => producto.precioMayorista * cantidad;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      producto: CatalogoProducto.fromJson(json['producto'] as Map<String, dynamic>),
      cantidad: json['cantidad'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'producto': producto.toJson(),
      'cantidad': cantidad,
    };
  }
}
