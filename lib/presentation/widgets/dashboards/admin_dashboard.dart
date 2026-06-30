import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/producto.dart';
import 'package:gestor_invetarios_pedidos_app/core/utils/numeric_utils.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/custom_data_table.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class AdminDashboard extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const AdminDashboard({super.key, required this.profile});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _currentView = 'stats'; // 'stats' or 'products'

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentView == 'stats')
          ordersAsync.when(
            data: (orders) => productsAsync.when(
              data: (products) => _buildStatsView(context, orders, products.length),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          )
        else
          _buildProductsView(context),
      ],
    );
  }

  Widget _buildStatsView(BuildContext context, List<Map<String, dynamic>> orders, int productCount) {
    final int totalPedidos = orders.length;
    
    double totalVendido = 0.0;
    double totalGananciaEsperada = 0.0;
    for (var o in orders) {
      final double total = double.tryParse(o['capital_invertido']?.toString() ?? '0.0') ?? 0.0;
      final double profit = double.tryParse(o['ganancia_esperada']?.toString() ?? '0.0') ?? 0.0;
      totalVendido += total;
      totalGananciaEsperada += profit;
    }
    
    final double margenPromedio = totalVendido > 0 ? (totalGananciaEsperada / totalVendido) * 100 : 0.0;

    final int deliveredCount = orders.where((o) => o['estado']?.toString().toLowerCase() == 'entregado').length;
    final int pendingCount = orders.where((o) => o['estado']?.toString().toLowerCase() == 'pendiente').length;

    final Map<String, int> productCounts = {};
    for (var o in orders) {
      final items = o['items'] as List<dynamic>?;
      if (items != null) {
        for (var item in items) {
          final name = item['nombre']?.toString() ?? 'Otro';
          final qty = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
          productCounts[name] = (productCounts[name] ?? 0) + qty;
        }
      } else {
        final name = o['producto_nombre']?.toString() ?? 'Otro';
        productCounts[name] = (productCounts[name] ?? 0) + 1;
      }
    }
    final topProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, Map<String, dynamic>> userStats = {};
    for (var o in orders) {
      final userName = o['comprador_nombre']?.toString() ?? 'Comprador Anónimo';
      final total = double.tryParse(o['capital_invertido']?.toString() ?? '0.0') ?? 0.0;
      if (!userStats.containsKey(userName)) {
        userStats[userName] = {'count': 0, 'spent': 0.0};
      }
      userStats[userName]!['count'] = (userStats[userName]!['count'] as int) + 1;
      userStats[userName]!['spent'] = (userStats[userName]!['spent'] as double) + total;
    }
    final sortedUsers = userStats.entries.toList()
      ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsGrid(context, totalPedidos, productCount, totalVendido, margenPromedio),
        const SizedBox(height: 32),
        const Text(
          'INTELIGENCIA DE NEGOCIO 📊',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        _buildChartsRow(deliveredCount, pendingCount, topProducts),
        const SizedBox(height: 32),
        const Text(
          'CLIENTES FRECUENTES ALY 🏆',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        _buildFrequentUsersList(sortedUsers),
        const SizedBox(height: 32),
        const Text(
          'ACCIONES DE CONTROL ⚙️',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildProductsView(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentView = 'stats'),
              icon: const Icon(Icons.arrow_back, color: AppTheme.accentOrange),
            ),
            const SizedBox(width: 8),
            Text('GESTIÓN DE PRODUCTOS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _showProductDialog(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
          child: const Text('➕ NUEVO PRODUCTO'),
        ),
        const SizedBox(height: 24),
        productsAsync.when(
          data: (products) => CustomDataTable(
            headers: const ['ID', 'NOMBRE', 'TIPO', 'PRECIO'],
            rows: products.map((p) => [
              p.id.toString(),
              p.nombre,
              p.tipoProducto,
              'S/ ${parseDoubleSafe(p.precioReferencia).toStringAsFixed(2)}',
            ]).toList(),
            columnWidths: const [60, 140, 120, 100],
            onEdit: (idx) => _showProductDialog(context, product: products[idx]),
            onDelete: (idx) => _handleDeleteProduct(products[idx].id),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, int totalPedidos, int productCount, double totalVendido, double margenPromedio) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 700;

    String formatMoney(double val) {
      if (val >= 1000) {
        return 'S/ ${(val / 1000).toStringAsFixed(1)}k';
      }
      return 'S/ ${val.toStringAsFixed(0)}';
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.0 : 1.6,
      children: [
        _statCard('TOTAL PEDIDOS', '$totalPedidos', Icons.assignment_outlined, AppTheme.accentOrange),
        _statCard('PROD. ACTIVOS', '$productCount', Icons.inventory_2_outlined, const Color(0xFF6366F1)),
        _statCard('GANANCIA REAL', formatMoney(totalVendido), Icons.trending_up, const Color(0xFF10B981)),
        _statCard('MARGEN PROM.', '${margenPromedio.toStringAsFixed(1)}%', Icons.pie_chart_outline, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildChartsRow(int deliveredCount, int pendingCount, List<MapEntry<String, int>> topProducts) {
    final total = deliveredCount + pendingCount;
    final double deliveredPct = total > 0 ? (deliveredCount / total) * 100 : 65.0;
    final double pendingPct = total > 0 ? (pendingCount / total) * 100 : 35.0;

    final String p1 = topProducts.isNotEmpty ? topProducts[0].key : 'Cemento';
    final double v1 = topProducts.isNotEmpty ? topProducts[0].value.toDouble() : 8.0;

    final String p2 = topProducts.length > 1 ? topProducts[1].key : 'Silicona';
    final double v2 = topProducts.length > 1 ? topProducts[1].value.toDouble() : 5.0;

    final String p3 = topProducts.length > 2 ? topProducts[2].key : 'Pintura';
    final double v3 = topProducts.length > 2 ? topProducts[2].value.toDouble() : 3.0;

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          // Gráfico de Torta: Pedidos
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTADO DE PEDIDOS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: deliveredPct, 
                                  color: const Color(0xFF10B981), 
                                  radius: 12, 
                                  showTitle: true,
                                  title: '${deliveredPct.toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: pendingPct, 
                                  color: const Color(0xFF3B82F6), 
                                  radius: 12, 
                                  showTitle: true,
                                  title: '${pendingPct.toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                              centerSpaceRadius: 28,
                              sectionsSpace: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legendRow(const Color(0xFF10B981), 'Entregados ($deliveredCount)'),
                              const SizedBox(height: 8),
                              _legendRow(const Color(0xFF3B82F6), 'Pendientes ($pendingCount)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Gráfico de Barras: Ventas
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRODUCTOS MÁS COMPRADOS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return Text(p1.length > 8 ? '${p1.substring(0, 6)}..' : p1, style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold));
                                  case 1:
                                    return Text(p2.length > 8 ? '${p2.substring(0, 6)}..' : p2, style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold));
                                  case 2:
                                    return Text(p3.length > 8 ? '${p3.substring(0, 6)}..' : p3, style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold));
                                  default:
                                    return const Text('');
                                }
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: v1, color: AppTheme.accentOrange, width: 12, borderRadius: BorderRadius.circular(3))]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: v2, color: const Color(0xFF10B981), width: 12, borderRadius: BorderRadius.circular(3))]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: v3, color: const Color(0xFF3B82F6), width: 12, borderRadius: BorderRadius.circular(3))]),
                        ],
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFrequentUsersList(List<MapEntry<String, Map<String, dynamic>>> sortedUsers) {
    final displayUsers = sortedUsers.take(5).toList();
    if (displayUsers.isEmpty) {
      return const GlassContainer(
        padding: EdgeInsets.all(16),
        borderRadius: 12,
        child: Center(
          child: Text('No hay clientes registrados aún.', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COMPRADOR', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              Text('COMPRAS', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              Text('TOTAL INVERTIDO', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayUsers.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 16),
            itemBuilder: (context, idx) {
              final entry = displayUsers[idx];
              final name = entry.key;
              final count = entry.value['count'] as int;
              final spent = entry.value['spent'] as double;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('👤', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                    ],
                  ),
                  Text('$count pedidos', style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
                  Text('S/ ${spent.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _primaryAction('CREAR NUEVO PEDIDO', Icons.add_circle_outline, () {}),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _secondaryAction('PRODUCTOS', Icons.inventory_2_outlined, () => setState(() => _currentView = 'products'))),
            const SizedBox(width: 12),
            Expanded(child: _secondaryAction('USUARIOS', Icons.people_outline, () {})),
          ],
        ),
      ],
    );
  }

  Widget _primaryAction(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.industrialGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _secondaryAction(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textGray, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: AppTheme.textGray)),
          ],
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Producto? product}) {
    final isEdit = product != null;
    final name = TextEditingController(text: isEdit ? product.nombre : '');
    final type = TextEditingController(text: isEdit ? product.tipoProducto : '');
    final price = TextEditingController(text: isEdit ? product.precioReferencia.toString() : '');
    final desc = TextEditingController(text: isEdit ? product.descripcion ?? '' : '');
    final imageUrl = TextEditingController(text: isEdit ? product.imagenUrl ?? '' : '');
    String? selectedDistributorId = isEdit ? product.distribuidorId : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              children: [
                Icon(isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded, color: AppTheme.accentOrange),
                const SizedBox(width: 12),
                Text(isEdit ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppTheme.textGray, size: 20)),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOMBRE DEL PRODUCTO *', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(hintText: 'Ej: Cemento Portland')),
                const SizedBox(height: 16),
                const Text('TIPO DE PRODUCTO *', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                const SizedBox(height: 8),
                TextField(controller: type, decoration: const InputDecoration(hintText: 'Ej: Material Construcción')),
                const SizedBox(height: 16),
                const Text('DISTRIBUIDOR ASIGNADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                const SizedBox(height: 8),
                ref.watch(distributorsFutureProvider).when(
                  data: (distribs) => DropdownButtonFormField<String>(
                    value: selectedDistributorId,
                    dropdownColor: AppTheme.surfaceDark,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguno', style: TextStyle(color: AppTheme.textGray))),
                      ...distribs.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text(d['nombre'] ?? ''))),
                    ],
                    onChanged: (v) => setState(() => selectedDistributorId = v),
                    decoration: const InputDecoration(hintText: 'Distribuidor'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error al cargar distribuidores'),
                ),
                const SizedBox(height: 16),
                const Text('PRECIO DE REFERENCIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                const SizedBox(height: 8),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0.00', prefixText: 'S/ ')),
                const SizedBox(height: 16),
                const Text('URL DE IMAGEN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                const SizedBox(height: 8),
                TextField(
                  controller: imageUrl,
                  decoration: const InputDecoration(hintText: 'https://...'),
                  onChanged: (val) => setState(() {}),
                ),
                if (imageUrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('VISTA PREVIA DE LA IMAGEN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl.text.trim(),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: AppTheme.textGray, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                final api = ref.read(apiServiceProvider);
                final data = {
                  'nombre': name.text,
                  'tipo_producto': type.text,
                  'precio_referencia': double.tryParse(price.text) ?? 0.0,
                  'descripcion': desc.text,
                  'imagen_url': imageUrl.text,
                  'distribuidor_id': selectedDistributorId,
                };
                if (isEdit) await api.updateProducto(product.id, data);
                else await api.createProducto(data);
                ref.refresh(productsStreamProvider);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('BORRAR PRODUCTO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text('¿Estás seguro de eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed), child: const Text('BORRAR')),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(apiServiceProvider).deleteProducto(id);
      ref.refresh(productsStreamProvider);
    }
  }
}
