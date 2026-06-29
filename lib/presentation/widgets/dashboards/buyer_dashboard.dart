import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/buyer_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/core/utils/numeric_utils.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/mayorista_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/custom_data_table.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/wholesale/create_wholesale_sale_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/billing/account_statement_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class BuyerDashboard extends ConsumerWidget {
  final Map<String, dynamic> profile;
  const BuyerDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(buyerNavProvider);

    switch (currentSection) {
      case BuyerSection.dashboard:
        return _buildDashboardView(context, ref);
      case BuyerSection.orders:
        return _buildInventoryView(ref);
      case BuyerSection.myProducts:
        return _buildMyProductsView(ref);
      case BuyerSection.invoicing:
        return _buildInvoicingView(context, ref);
      case BuyerSection.wholesaleSales:
        return _buildWholesaleSalesView(ref);
      default:
        return _buildDashboardView(context, ref);
    }
  }

  // ─── VISTA: DASHBOARD ───
  Widget _buildDashboardView(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('🛒 DASHBOARD COMPRADOR', 'Gestión operativa y financiera de inversiones.'),
        const SizedBox(height: 16),
        ordersAsync.when(
          data: (orders) => _buildStatsGrid(context, orders),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const SizedBox(),
        ),
        const SizedBox(height: 32),
        const Text('ANÁLISIS DE FLUJO 📈', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray)),
        const SizedBox(height: 16),
        _buildChartsRow(),
        const SizedBox(height: 32),
        const Text('📋 PEDIDOS EN CURSO / GESTIÓN DE PAGOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
        const SizedBox(height: 16),
        _buildOrdersToChargeTable(ref),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, List<Map<String, dynamic>> orders) {
    double gestionado = 0;
    double devuelto = 0;
    double ganGenerada = 0;
    
    for (var o in orders) {
      gestionado += parseDoubleSafe(o['capital_invertido']);
      // Usar la suma mayor para evitar pérdida de datos entre tabla pedidos y subqueries
      double d1 = parseDoubleSafe(o['devolucion_capital']);
      double d2 = parseDoubleSafe(o['capital_devuelto']);
      devuelto += (d1 > d2 ? d1 : d2);
      
      double g1 = parseDoubleSafe(o['ganancia_real']);
      double g2 = parseDoubleSafe(o['ganancia_devuelta_real']);
      double g3 = parseDoubleSafe(o['ganancia_devuelta_monto']);
      ganGenerada += (g1 > g2 ? (g1 > g3 ? g1 : g3) : (g2 > g3 ? g2 : g3));
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 700;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 3 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.2 : 1.8,
      children: [
        _statCard('CAPITAL GESTIONADO', 'S/ ${gestionado.toStringAsFixed(2)}', AppTheme.accentOrange),
        _statCard('CAPITAL DEVUELTO', 'S/ ${devuelto.toStringAsFixed(2)}', AppTheme.successGreen),
        _statCard('PENDIENTE DEVOLVER', 'S/ ${(gestionado - devuelto).toStringAsFixed(2)}', AppTheme.errorRed),
        _statCard('TOTAL PEDIDOS', orders.length.toString(), Colors.blueAccent),
        _statCard('GANANCIA GENERADA', 'S/ ${ganGenerada.toStringAsFixed(2)}', Colors.amberAccent),
        _statCard('% DEVUELTO', '${gestionado > 0 ? ((devuelto / gestionado) * 100).toStringAsFixed(1) : 0.0}%', AppTheme.accentOrange),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return SizedBox(height: 180, child: Row(children: [
      Expanded(child: _chartContainer('Historial de Capital', _buildCapitalHistoryChart())),
      const SizedBox(width: 12),
      Expanded(child: _chartContainer('Distribución Estados', _buildStatusPieChart())),
    ]));
  }

  Widget _chartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.textGray)),
        const SizedBox(height: 12),
        Expanded(child: chart),
      ]),
    );
  }

  Widget _buildCapitalHistoryChart() => LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: [const FlSpot(0, 3), const FlSpot(1, 4), const FlSpot(2, 5), const FlSpot(3, 7)], isCurved: true, color: AppTheme.accentOrange, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppTheme.accentOrange.withOpacity(0.05)))]));

  Widget _buildStatusPieChart() => PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 20, sections: [PieChartSectionData(color: AppTheme.accentOrange, value: 40, title: 'Pend.', radius: 24, titleStyle: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)), PieChartSectionData(color: AppTheme.successGreen, value: 35, title: 'Dev.', radius: 24, titleStyle: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)), PieChartSectionData(color: Colors.blueAccent, value: 25, title: 'Proceso', radius: 24, titleStyle: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))]));

  Widget _buildOrdersToChargeTable(WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);
    return ordersAsync.when(
      data: (orders) => CustomDataTable(
        headers: const ['#', 'PRODUCTO', 'INVERSIONISTA', 'CAPITAL', 'DEVUELTO', 'ESTADO'],
        rows: orders.map((o) {
          final capital = parseDoubleSafe(o['capital_invertido']);
          final devuelto = parseDoubleSafe(o['devolucion_capital']);
          return [
            o['id'].toString(),
            o['items']?[0]?['nombre'] ?? o['producto_nombre'] ?? 'N/A',
            o['inversionista_nombre'] ?? 'INVERSIONISTA',
            'S/ ${capital.toStringAsFixed(2)}',
            'S/ ${devuelto.toStringAsFixed(2)}',
            (o['estado'] ?? 'pendiente').toString().toUpperCase(),
          ];
        }).toList(),
        columnWidths: const [40, 120, 150, 100, 100, 100],
        showActions: false, // Esta tabla es informativa + botones abajo
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  // ─── VISTA: GESTIÓN DE PEDIDOS ───
  Widget _buildInventoryView(WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('📋 GESTIÓN DE PEDIDOS', 'Administra y audita las herramientas en tránsito.'),
        const SizedBox(height: 24),
        ordersAsync.when(
          data: (orders) => CustomDataTable(
            headers: const ['ID', 'FECHA', 'PRODUCTO', 'INVERSIONISTA', 'CAPITAL', 'ESTADO'],
            rows: orders.map((o) => [
              o['id'].toString(),
              (o['fecha_pedido'] ?? '-').toString().split('T')[0],
              o['producto_nombre'] ?? 'VARIOS',
              o['inversionista_nombre'] ?? 'N/A',
              'S/ ${parseDoubleSafe(o['capital_invertido']).toStringAsFixed(2)}',
              (o['estado'] ?? 'pendiente').toUpperCase(),
            ]).toList(),
            columnWidths: const [40, 90, 130, 130, 100, 100],
            onEdit: (idx) => _handleEditOrder(ref, orders[idx]),
            onDelete: (idx) => _handleDeleteOrder(ref, orders[idx]['id']),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── VISTA: MIS PRODUCTOS (STOCK MAYORISTA) ───
  Widget _buildMyProductsView(WidgetRef ref) {
    final stockAsync = ref.watch(mayoristaStockProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('💎 MIS PRODUCTOS', 'Visualiza el stock disponible para ventas mayoristas.'),
        const SizedBox(height: 24),
        stockAsync.when(
          data: (stocks) => CustomDataTable(
            headers: const ['TIPO', 'MARCA', 'DISPONIBLE', 'ESTADO'],
            rows: stocks.map((s) => [
              s.tipo.toUpperCase(),
              s.marca,
              s.disponible.toString(),
              s.disponible > 0 ? 'LISTO' : 'AGOTADO'
            ]).toList(),
            columnWidths: const [100, 130, 100, 100],
            showActions: false,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── VISTA: FACTURACIÓN ───
  Widget _buildInvoicingView(BuildContext context, WidgetRef ref) {
    final distributorsAsync = ref.watch(distributorsFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('📄 FACTURACIÓN POR DISTRIBUIDOR', 'Selecciona un distribuidor para gestionar abonos.'),
        const SizedBox(height: 24),
        distributorsAsync.when(
          data: (distribs) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5),
            itemCount: distribs.length,
            itemBuilder: (ctx, idx) => _distributorCard(ref, distribs[idx]),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _distributorCard(WidgetRef ref, Map<String, dynamic> d) {
    return InkWell(
      onTap: () => Navigator.push(ref.context, MaterialPageRoute(builder: (c) => AccountStatementScreen(compradorId: profile['id'], distribuidorId: d['id'], distribuidorNombre: d['nombre']))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_rounded, color: AppTheme.accentOrange, size: 30),
            const SizedBox(height: 12),
            Text(d['nombre'] ?? 'N/A', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 4),
            Text(d['contacto'] ?? '', style: const TextStyle(fontSize: 8, color: AppTheme.textGray)),
          ],
        ),
      ),
    );
  }

  // ─── VISTA: VENTAS MAYORISTAS ───
  Widget _buildWholesaleSalesView(WidgetRef ref) {
    final salesAsync = ref.watch(mayoristaVentasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionHeader('📦 VENTAS MAYORISTAS', 'Historial de ventas de stock final.')),
            ElevatedButton(onPressed: () => _handleNewSale(ref), child: const Text('NUEVA VENTA')),
          ],
        ),
        const SizedBox(height: 24),
        salesAsync.when(
          data: (sales) => CustomDataTable(
            headers: const ['#', 'CLIENTE', 'FECHA', 'TOTAL', 'ESTADO'],
            rows: sales.map((s) => [
              s.id.toString(),
              s.clienteNombre ?? 'CLIENTE',
              s.fechaVenta.toString().split(' ')[0],
              'S/ ${s.total.toStringAsFixed(2)}',
              s.estado.toUpperCase()
            ]).toList(),
            columnWidths: const [40, 130, 90, 100, 100],
            showActions: false,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── HELPERS ───
  void _handleDeleteOrder(WidgetRef ref, int id) async {
    final confirm = await _showConfirm(ref.context, '¿Borrar este pedido?');
    if (confirm) {
      await ref.read(apiServiceProvider).deletePedido(id);
      ref.refresh(ordersFutureProvider);
    }
  }

  void _handleEditOrder(WidgetRef ref, Map<String, dynamic> order) {
    // Implementación pendiente si se requiere edición operativa específica
  }

  void _handleNewSale(WidgetRef ref) {
    Navigator.push(ref.context, MaterialPageRoute(builder: (c) => CreateWholesaleSaleScreen(compradorId: profile['id'])));
  }

  Future<bool> _showConfirm(BuildContext context, String msg) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('CONFIRMAR'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar'))],
      ),
    ) ?? false;
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textGray)),
      ],
    );
  }
}
