import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final appBar = AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text('PEDIDOS ALY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );

    final mainContent = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ordersAsync.when(
          data: (orders) => _buildOrderList(orders),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange)),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'orders'),
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text('No hay pedidos registrados.', style: TextStyle(color: AppTheme.textGray)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        return _orderCard(
          o['id_pedido'] ?? 'PED-000',
          o['fecha'] ?? 'N/A',
          o['producto'] ?? 'Producto Desconocido',
          'S/ ${o['capital_invertido'] ?? '0.00'}',
          o['estado'] ?? 'PENDIENTE',
        );
      },
    );
  }

  Widget _orderCard(String id, String date, String product, String price, String status) {
    final bool isPending = status.toUpperCase() == 'PENDIENTE';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    id,
                    style: const TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                  ),
                  Text(date, style: const TextStyle(color: AppTheme.textGray, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? AppTheme.accentOrange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isPending ? AppTheme.accentOrange : Colors.green,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('🚜', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PRODUCTO PRINCIPAL', style: TextStyle(fontSize: 8, color: AppTheme.textGray, fontWeight: FontWeight.w900)),
                    Text(product, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('INVERSIÓN', style: TextStyle(fontSize: 8, color: AppTheme.textGray, fontWeight: FontWeight.w900)),
                  Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
