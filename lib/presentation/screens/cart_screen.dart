import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/cart_item.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/cart_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/payment_gateway_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const Map<String, IconData> _categoryIcons = {
    'Herramientas Manuales': Icons.build_rounded,
    'Herramientas Eléctricas': Icons.electrical_services_rounded,
    'Materiales de Construcción': Icons.apartment_rounded,
    'Seguridad Industrial': Icons.shield_rounded,
    'Fijaciones y Tornillería': Icons.settings_rounded,
    'Abrasivos y Consumibles': Icons.auto_fix_high_rounded,
  };

  static const Map<String, Color> _categoryColors = {
    'Herramientas Manuales': Color(0xFF3B82F6),
    'Herramientas Eléctricas': Color(0xFFF59E0B),
    'Materiales de Construcción': Color(0xFF10B981),
    'Seguridad Industrial': Color(0xFFEF4444),
    'Fijaciones y Tornillería': Color(0xFF8B5CF6),
    'Abrasivos y Consumibles': Color(0xFFEC4899),
  };

  String _getProductImage(CatalogoProducto producto) {
    if (producto.imagenUrl != null && producto.imagenUrl!.trim().isNotEmpty) {
      return producto.imagenUrl!;
    }
    switch (producto.categoria) {
      case 'Herramientas Manuales':
        return 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop';
      case 'Herramientas Eléctricas':
        return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop';
      case 'Materiales de Construcción':
        return 'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=500&auto=format&fit=crop';
      case 'Seguridad Industrial':
        return 'https://images.unsplash.com/photo-1508962914676-134849a727f0?w=500&auto=format&fit=crop';
      case 'Fijaciones y Tornillería':
        return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop';
      case 'Abrasivos y Consumibles':
        return 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=500&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final totalUnitario = ref.watch(cartTotalProvider);
    final totalMayorista = ref.watch(cartTotalMayoristaProvider);
    final savings = totalUnitario - totalMayorista;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'MI CARRITO',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.errorRed, size: 24),
              tooltip: 'Vaciar Carrito',
              onPressed: () => _confirmClearCart(context, ref),
            ),
        ],
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      body: cartItems.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _buildCartItemCard(context, ref, item);
                    },
                  ),
                ),
                _buildSummarySection(context, ref, totalUnitario, totalMayorista, savings),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentOrange.withOpacity(0.1)),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: AppTheme.accentOrange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Tu carrito está vacío!',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega productos del catálogo para comenzar a comprar.',
            style: TextStyle(color: AppTheme.textGray, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('VOLVER AL CATÁLOGO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDark,
              foregroundColor: AppTheme.accentOrange,
              side: const BorderSide(color: AppTheme.accentOrange, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, CartItem item) {
    final prod = item.producto;
    final color = _categoryColors[prod.categoria] ?? AppTheme.accentOrange;
    final icon = _categoryIcons[prod.categoria] ?? Icons.category_rounded;
    final imageUrl = _getProductImage(prod);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 110,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Imagen del producto
            Container(
              width: 90,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.04)),
                ),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 180,
                cacheHeight: 220,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: color.withOpacity(0.1),
                  child: Center(
                    child: Icon(icon, color: color, size: 28),
                  ),
                ),
              ),
            ),
            // Detalles del producto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${prod.marca} · ${prod.unidad}',
                          style: const TextStyle(
                            color: AppTheme.textGray,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'S/ ${prod.precioUnitario.toStringAsFixed(2)} c/u',
                              style: const TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'S/ ${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        // Controles de cantidad
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 14, color: AppTheme.textGray),
                                onPressed: () => ref.read(cartProvider.notifier).decrementItem(prod.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 14, color: AppTheme.accentOrange),
                                onPressed: () => ref.read(cartProvider.notifier).incrementItem(prod.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Eliminar botón lateral
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textGray),
              onPressed: () => ref.read(cartProvider.notifier).removeItem(prod.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, WidgetRef ref, double totalUnit, double totalMay, double savings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal Minorista:',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 13),
                ),
                Text(
                  'S/ ${totalUnit.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Mayorista:',
                  style: TextStyle(color: AppTheme.successGreen, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'S/ ${totalMay.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.successGreen, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (savings > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ahorro Mayorista:',
                      style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '- S/ ${savings.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL A PAGAR',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'S/ ${totalUnit.toStringAsFixed(2)}', // Cobramos al precio unitario estándar por defecto, y guardamos el descuento
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accentOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PaymentGatewayScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PROCEDER AL PAGO',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearCart(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Vaciar Carrito',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          '¿Estás seguro de que deseas vaciar tu carrito de compras?',
          style: TextStyle(color: AppTheme.textGray),
        ),
        actions: [
          TextButton(
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('VACIAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
