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
}
