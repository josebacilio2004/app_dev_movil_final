import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/investor_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/core/utils/numeric_utils.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/buyer_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/custom_data_table.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/producto.dart';
import 'package:fl_chart/fl_chart.dart';

class InvestorDashboard extends ConsumerWidget {
  final Map<String, dynamic> profile;
  const InvestorDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(investorNavProvider);

    switch (currentSection) {
      case InvestorSection.inventoryManager:
      case InvestorSection.dashboard:
        return _buildDashboardView(context, ref);
      case InvestorSection.orders:
        return _buildOrdersView(ref);
      case InvestorSection.products:
        return _buildProductsView(ref);
      case InvestorSection.distributors:
        return _buildDistributorsView(ref);
      case InvestorSection.buyers:
        return _buildBuyersView(ref);
      default:
        return _buildDashboardView(context, ref);
    }
  }

  // ─── VISTA: DASHBOARD / GESTOR DE INVENTARIO ───
  Widget _buildDashboardView(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ordersAsync.when(
          data: (orders) => _buildStatsGrid(context, orders),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const SizedBox(),
        ),
        const SizedBox(height: 32),
        Text(
          'ANÁLISIS DE RENDIMIENTO 📊',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        _buildChartsRow(),
        const SizedBox(height: 32),
        const Text(
          '📋 DETALLE DE MIS INVERSIONES',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5, color: Colors.white),
        ),
        const SizedBox(height: 16),
        _buildInvestmentTable(ref),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, List<Map<String, dynamic>> orders) {
    double totalInvertido = 0;
    double devuelto = 0;
    double ganDevuelta = 0;
    double ganEsp = 0;

    for (var o in orders) {
      totalInvertido += parseDoubleSafe(o['capital_invertido']);
      
      // Lógica inteligente para no perder datos si vienen de diferentes tablas
      double d1 = parseDoubleSafe(o['devolucion_capital']);
      double d2 = parseDoubleSafe(o['capital_devuelto']);
      devuelto += (d1 > d2 ? d1 : d2);
      
      double g1 = parseDoubleSafe(o['ganancia_real']);
      double g2 = parseDoubleSafe(o['ganancia_devuelta_real']);
      double g3 = parseDoubleSafe(o['ganancia_devuelta_monto']);
      ganDevuelta += (g1 > g2 ? (g1 > g3 ? g1 : g3) : (g2 > g3 ? g2 : g3));
      
      ganEsp += parseDoubleSafe(o['ganancia_esperada']);
    }

    final capPendiente = totalInvertido - devuelto;
    final ganPendiente = ganEsp - ganDevuelta;
    final percDevolucion = totalInvertido > 0 ? (devuelto / totalInvertido) * 100 : 0.0;

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 700;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.0 : 1.8,
      children: [
        _statCard('CAPITAL TOTAL INVERTIDO', 'S/ ${totalInvertido.toStringAsFixed(2)}', AppTheme.accentOrange),
        _statCard('CAPITAL DEVUELTO', 'S/ ${devuelto.toStringAsFixed(2)}', AppTheme.successGreen),
        _statCard('CAPITAL PENDIENTE', 'S/ ${capPendiente.toStringAsFixed(2)}', AppTheme.errorRed),
        _statCard('TOTAL PEDIDOS', orders.length.toString(), Colors.blueAccent),
        _statCard('GANANCIA REAL', 'S/ ${ganEsp.toStringAsFixed(2)}', Colors.amberAccent),
        _statCard('GANANCIA DEVUELTA', 'S/ ${ganDevuelta.toStringAsFixed(2)}', AppTheme.successGreen),
        _statCard('GANANCIA PENDIENTE', 'S/ ${ganPendiente.toStringAsFixed(2)}', AppTheme.textGray),
        _statCard('% DEVOLUCIÓN', '${percDevolucion.toStringAsFixed(1)}%', AppTheme.accentOrange),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(child: _chartContainer('Inversión vs Devolución', _buildPieChart())),
          const SizedBox(width: 12),
          Expanded(child: _chartContainer('Progreso Ganancias', _buildBarChart())),
        ],
      ),
    );
  }

  Widget _chartContainer(String title, Widget chart) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(value: 65, color: AppTheme.accentOrange, radius: 6, showTitle: false),
          PieChartSectionData(value: 35, color: Colors.white.withOpacity(0.05), radius: 6, showTitle: false),
        ],
        centerSpaceRadius: 25,
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 12, color: AppTheme.accentOrange, width: 10, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 8, color: Colors.blueAccent, width: 10, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 15, color: AppTheme.successGreen, width: 10, borderRadius: BorderRadius.circular(4))]),
        ],
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
      ),
    );
  }

  Widget _buildInvestmentTable(WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);
    return ordersAsync.when(
      data: (orders) => CustomDataTable(
        headers: const ['#', 'FECHA', 'PRODUCTO', 'CANT.', 'INVEST.', 'DEV.', 'GAN.', 'ESTADO'],
        rows: orders.map((o) => [
          o['id'].toString(),
          (o['fecha_pedido'] ?? '-').toString().split('T')[0],
          o['items']?[0]?['nombre'] ?? o['producto_nombre'] ?? 'VARIOS',
          o['cantidad']?.toString() ?? '1',
          'S/ ${parseDoubleSafe(o['capital_invertido']).toStringAsFixed(2)}',
          'S/ ${parseDoubleSafe(o['capital_devuelto'] ?? o['devolucion_capital']).toStringAsFixed(2)}',
          'S/ ${(() {
            double g1 = parseDoubleSafe(o['ganancia_real']);
            double g2 = parseDoubleSafe(o['ganancia_devuelta_real']);
            double g3 = parseDoubleSafe(o['ganancia_devuelta_monto']);
            return (g1 > g2 ? (g1 > g3 ? g1 : g3) : (g2 > g3 ? g2 : g3));
          })().toStringAsFixed(2)}',
          o['estado']?.toString().toUpperCase() ?? 'PENDIENTE',
        ]).toList(),
        columnWidths: const [40, 90, 120, 50, 80, 80, 80, 100],
        onEdit: (idx) => _showEditOrderDialog(ref.context, ref, orders[idx]),
        onDelete: (idx) => _handleDeleteOrder(ref, orders[idx]['id']),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  // ─── VISTA: PRODUCTOS ───
  Widget _buildProductsView(WidgetRef ref) {
    final productsAsync = ref.watch(productsFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('📦 GESTIÓN DE PRODUCTOS', 'Administra tu catálogo de productos de ferretería'),
        _buildActionBtn(ref, '➕ NUEVO PRODUCTO', () => _showProductDialog(ref.context, ref)),
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
            onEdit: (idx) => _showProductDialog(ref.context, ref, product: products[idx]),
            onDelete: (idx) => _handleDeleteProduct(ref, products[idx].id),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── VISTA: DISTRIBUIDORES ───
  Widget _buildDistributorsView(WidgetRef ref) {
    final distributorsAsync = ref.watch(distributorsFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('🏭 GESTIÓN DE DISTRIBUIDORES', 'Administra tu red de proveedores'),
        _buildActionBtn(ref, '➕ NUEVO DISTRIBUIDOR', () => _showDistributorDialog(ref.context, ref)),
        const SizedBox(height: 24),
        distributorsAsync.when(
          data: (distributors) => CustomDataTable(
            headers: const ['ID', 'NOMBRE', 'CONTACTO', 'TELÉFONO'],
            rows: distributors.map((d) => [
              d['id'].toString(),
              d['nombre'] ?? '',
              d['contacto'] ?? '',
              d['telefono'] ?? '',
            ]).toList(),
            columnWidths: const [60, 150, 120, 100],
            onEdit: (idx) => _showDistributorDialog(ref.context, ref, distributor: distributors[idx]),
            onDelete: (idx) => _handleDeleteDistributor(ref, distributors[idx]['id']),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── VISTA: PEDIDOS ───
  Widget _buildOrdersView(WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('📋 GESTIÓN DE PEDIDOS', 'Registra y monitorea tus pedidos'),
        _buildActionBtn(ref, '➕ NUEVO PEDIDO', () => _showOrderDialog(ref.context, ref)),
        const SizedBox(height: 24),
        ordersAsync.when(
          data: (orders) => CustomDataTable(
            headers: const ['ID', 'FECHA', 'PRODUCTO', 'DISTRIB.', 'ESTADO'],
            rows: orders.map((o) => [
              o['id'].toString(),
              (o['fecha_pedido'] ?? '-').toString().split('T')[0],
              o['items']?[0]?['nombre'] ?? o['producto_nombre'] ?? 'VARIOS',
              o['distribuidor_nombre'] ?? 'N/A',
              o['estado']?.toString().toUpperCase() ?? 'PENDIENTE',
            ]).toList(),
            columnWidths: const [40, 90, 130, 130, 100],
            onEdit: (idx) => _showOrderDialog(ref.context, ref, order: orders[idx]),
            onDelete: (idx) => _handleDeleteOrder(ref, orders[idx]['id']),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── VISTA: COMPRADORES ───
  Widget _buildBuyersView(WidgetRef ref) {
    final buyersAsync = ref.watch(buyersFutureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('🛒 GESTIÓN DE COMPRADORES', 'Monitorea el desempeño de tus gestores operativos'),
        const SizedBox(height: 24),
        buyersAsync.when(
          data: (buyers) => CustomDataTable(
            headers: const ['ID', 'NOMBRE', 'TELEFONO', 'ACCIONES'],
            rows: buyers.map((b) => [
              b['id'].toString(),
              b['nombre'] ?? '',
              b['telefono'] ?? '',
              'VER DETALLE',
            ]).toList(),
            columnWidths: const [60, 150, 120, 120],
            showActions: false,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  // ─── CRUD HANDLERS ───
  void _handleDeleteOrder(WidgetRef ref, String id) async {
    final confirm = await _showDeleteConfirm(ref.context, '¿Borrar este pedido?');
    if (confirm) {
      await ref.read(apiServiceProvider).deletePedido(id);
      ref.refresh(ordersFutureProvider);
    }
  }

  void _handleDeleteProduct(WidgetRef ref, String id) async {
    final confirm = await _showDeleteConfirm(ref.context, '¿Borrar este producto?');
    if (confirm) {
      await ref.read(apiServiceProvider).deleteProducto(id);
      ref.refresh(productsFutureProvider);
    }
  }

  void _handleDeleteDistributor(WidgetRef ref, String id) async {
    final confirm = await _showDeleteConfirm(ref.context, '¿Borrar distribuidor?');
    if (confirm) {
      await ref.read(apiServiceProvider).deleteDistribuidor(id);
      ref.refresh(distributorsFutureProvider);
    }
  }

  Future<bool> _showDeleteConfirm(BuildContext context, String msg) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('CONFIRMAR BORRADO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed), child: const Text('BORRAR')),
        ],
      ),
    ) ?? false;
  }

  // ─── DIÁLOGOS DE REGISTRO (WEB PARITY) ───
  void _showOrderDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? order}) {
    final isEdit = order != null;
    final dateController = TextEditingController(text: isEdit ? order['fecha_pedido'].split('T')[0] : DateTime.now().toString().split(' ')[0]);
    final capitalController = TextEditingController(text: isEdit ? order['capital_invertido'].toString() : '');
    final profitController = TextEditingController(text: isEdit ? order['ganancia_esperada'].toString() : '');
    final notesController = TextEditingController(text: isEdit ? order['notas'] ?? '' : '');
    
    String? selectedDistributor = isEdit ? order['distribuidor_id']?.toString() : null;
    String? selectedComprador = isEdit ? order['comprador_id']?.toString() : null;
    
    List<Map<String, dynamic>> itemsList = isEdit ? List<Map<String, dynamic>>.from(order['items'] ?? []) : [];
    final qtyController = TextEditingController();
    String? tempProduct;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: Text(isEdit ? 'EDITAR PEDIDO #${order['id']}' : 'NUEVO PEDIDO DE INVERSIÓN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today))),
                const SizedBox(height: 12),
                ref.watch(distributorsFutureProvider).when(
                  data: (distribs) => DropdownButtonFormField<String>(
                    value: selectedDistributor,
                    decoration: const InputDecoration(labelText: 'Distribuidor'),
                    items: distribs.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text(d['nombre'] ?? ''))).toList(),
                    onChanged: (v) => selectedDistributor = v,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error cargando distribuidores'),
                ),
                const SizedBox(height: 12),
                ref.watch(buyersFutureProvider).when(
                  data: (buyers) => DropdownButtonFormField<String>(
                    value: selectedComprador,
                    decoration: const InputDecoration(labelText: 'Comprador Responsable'),
                    items: buyers.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(headSafe(b['nombre'], 'COMPRADOR')))).toList(),
                    onChanged: (v) => selectedComprador = v,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error cargando compradores'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ref.watch(productsFutureProvider).when(
                        data: (prods) => DropdownButtonFormField<String>(
                          value: tempProduct,
                          decoration: const InputDecoration(labelText: 'Producto'),
                          items: prods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))).toList(),
                          onChanged: (v) => tempProduct = v,
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cant.'))),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.accentOrange),
                      onPressed: () {
                        if (tempProduct != null && qtyController.text.isNotEmpty) {
                          setState(() {
                            itemsList.add({
                              'producto_id': tempProduct,
                              'cantidad': int.parse(qtyController.text),
                              'nombre': 'Item'
                            });
                          });
                        }
                      },
                    )
                  ],
                ),
                if (itemsList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: itemsList.asMap().entries.map((e) => ListTile(
                        dense: true,
                        title: Text('• ${e.value['cantidad']}x Producto', style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() => itemsList.removeAt(e.key))),
                      )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextField(controller: capitalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capital Inv.'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: profitController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ganancia Esp.'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                final api = ref.read(apiServiceProvider);
                final data = {
                  'fecha_pedido': dateController.text,
                  'distribuidor_id': selectedDistributor,
                  'inversionista_id': profile['id'],
                  'comprador_id': selectedComprador,
                  'cantidad': itemsList.fold<int>(0, (p, c) => p + (c['cantidad'] as int)),
                  'capital_invertido': double.parse(capitalController.text),
                  'ganancia_esperada': double.parse(profitController.text),
                  'items': itemsList,
                  'notas': notesController.text,
                  'estado': isEdit ? order['estado'] : 'pendiente'
                };
                if (isEdit) await api.updatePedido(order['id'], data);
                else await api.createPedido(data);
                ref.refresh(ordersFutureProvider);
                Navigator.pop(context);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, WidgetRef ref, {Producto? product}) {
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
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded, color: AppTheme.accentOrange),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: AppTheme.textGray, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOMBRE DEL PRODUCTO *', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(hintText: 'Ej: Cemento Portland 42.5kg')),
                
                const SizedBox(height: 16),
                const Text('TIPO DE PRODUCTO *', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(controller: type, decoration: const InputDecoration(hintText: 'Ej: Material Construcción')),
                
                const SizedBox(height: 16),
                const Text('DISTRIBUIDOR ASIGNADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                ref.watch(distributorsFutureProvider).when(
                  data: (distribs) => DropdownButtonFormField<String>(
                    value: selectedDistributorId,
                    dropdownColor: AppTheme.surfaceDark,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguno', style: TextStyle(color: AppTheme.textGray))),
                      ...distribs.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text(d['nombre'] ?? 'S/N'))),
                    ],
                    onChanged: (v) => setState(() => selectedDistributorId = v),
                    decoration: const InputDecoration(hintText: 'Seleccionar distribuidor'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error al cargar distribuidores'),
                ),
                
                const SizedBox(height: 16),
                const Text('PRECIO DE REFERENCIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '0.00', prefixText: 'S/ ')),
                
                const SizedBox(height: 16),
                const Text('DESCRIPCIÓN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(hintText: 'Detalles adicionales...')),
                
                const SizedBox(height: 16),
                const Text('URL DE IMAGEN (OPCIONAL)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textGray, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: imageUrl, 
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.image_outlined, size: 18),
                  ),
                ),
                if (imageUrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl.text,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
                      },
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        height: 40,
                        color: Colors.white.withOpacity(0.05),
                        child: const Center(child: Text('URL de imagen no válida', style: TextStyle(fontSize: 10, color: AppTheme.errorRed))),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textGray),
              child: const Text('CANCELAR'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || type.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre y Tipo son obligatorios')));
                  return;
                }

                final api = ref.read(apiServiceProvider);
                final data = {
                  'nombre': name.text,
                  'tipo_producto': type.text,
                  'precio_referencia': double.tryParse(price.text) ?? 0.0,
                  'descripcion': desc.text,
                  'imagen_url': imageUrl.text,
                  'distribuidor_id': selectedDistributorId,
                };
                
                try {
                  if (isEdit) await api.updateProducto(product.id, data);
                  else await api.createProducto(data);
                  
                  ref.refresh(productsFutureProvider);
                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                backgroundColor: AppTheme.accentOrange,
              ),
              child: Text(isEdit ? 'ACTUALIZAR' : 'GUARDAR PRODUCTO'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistributorDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? distributor}) {
    final isEdit = distributor != null;
    final name = TextEditingController(text: isEdit ? distributor['nombre'] : '');
    final contact = TextEditingController(text: isEdit ? distributor['contacto'] : '');
    final phone = TextEditingController(text: isEdit ? distributor['telefono'] : '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(isEdit ? 'EDITAR DISTRIBUIDOR' : 'NUEVO DISTRIBUIDOR', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Razón Social')),
            const SizedBox(height: 12),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contacto')),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiServiceProvider);
              final data = {'nombre': name.text, 'contacto': contact.text, 'telefono': phone.text};
              if (isEdit) await api.updateDistribuidor(distributor['id'], data);
              else await api.createDistribuidor(data);
              ref.refresh(distributorsFutureProvider);
              Navigator.pop(ctx);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _showEditOrderDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> order) => _showOrderDialog(context, ref, order: order);

  String headSafe(dynamic val, String fallback) => (val?.toString() ?? fallback);

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textGray)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(WidgetRef ref, String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentOrange,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
