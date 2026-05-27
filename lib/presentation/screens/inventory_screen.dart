import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/producto.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('INVENTARIO ALY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: productsAsync.when(
              data: (products) => _buildProductList(products),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.accentOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'BUSCAR PRODUCTO...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceDark,
        ),
      ),
    );
  }

  Widget _buildProductList(List<Producto> products) {
    if (products.isEmpty) {
      return const Center(child: Text('No hay productos registrados.', style: TextStyle(color: AppTheme.textGray)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return _productCard(
          p.nombre,
          p.distribuidorNombre ?? 'N/A',
          'S/ ${p.precioReferencia.toStringAsFixed(2)}',
          p.tipoProducto,
        );
      },
    );
  }

  Widget _productCard(String name, String supplier, String price, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('📦', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(color: AppTheme.accentOrange, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  supplier,
                  style: const TextStyle(color: AppTheme.textGray, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
