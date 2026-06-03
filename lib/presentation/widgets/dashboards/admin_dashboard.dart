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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentView == 'stats') _buildStatsView(context)
        else _buildProductsView(context),
      ],
    );
  }

  Widget _buildStatsView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsGrid(),
        const SizedBox(height: 32),
        const Text(
          'INTELIGENCIA DE NEGOCIO 📊',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        _buildChartsRow(),
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
    final productsAsync = ref.watch(productsFutureProvider);
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

  // --- MÉTODOS DE LA UI ORIGINAL --- (Adaptados para interactividad)

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _statCard('TOTAL PEDIDOS', '156', Icons.assignment_outlined, AppTheme.accentOrange),
        _statCard('PROD. ACTIVOS', '42', Icons.inventory_2_outlined, const Color(0xFF6366F1)),
        _statCard('GANANCIA REAL', 'S/ 12.4k', Icons.trending_up, const Color(0xFF10B981)),
        _statCard('MARGEN PROM.', '18%', Icons.pie_chart_outline, const Color(0xFF8B5CF6)),
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

  Widget _buildChartsRow() {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 12,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(value: 65, color: const Color(0xFF10B981), radius: 6, showTitle: false),
                    PieChartSectionData(value: 35, color: const Color(0xFF3B82F6), radius: 6, showTitle: false),
                  ],
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 12,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: AppTheme.accentOrange, width: 8)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: const Color(0xFF10B981), width: 8)]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 7, color: const Color(0xFF3B82F6), width: 8)]),
                  ],
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
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

  // --- DIÁLOGO PREMIUM PARA ADMIN ---

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
                TextField(controller: imageUrl, decoration: const InputDecoration(hintText: 'https://...')),
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
                ref.refresh(productsFutureProvider);
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
      ref.refresh(productsFutureProvider);
    }
  }
}

