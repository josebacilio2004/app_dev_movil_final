import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/seguimiento_delivery_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  String _formatDate(String dateRaw) {
    if (dateRaw == 'N/A' || dateRaw.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(dateRaw);
      return DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(parsed);
    } catch (_) {
      return dateRaw;
    }
  }

  Future<void> _iniciarSeguimiento(BuildContext context, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(orderId)
          .update({
        'tracking_enabled': true,
        'estado_tracking': 'en_camino',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Seguimiento de delivery iniciado! El cliente ya puede rastrearlo.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al habilitar delivery: $e')),
      );
    }
  }

  void _verMapa(BuildContext context, Map<String, dynamic> o, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeguimientoDeliveryScreen(
          orderId: id,
          destinoLat: o['latitud'] != null ? double.tryParse(o['latitud'].toString()) : null,
          destinoLng: o['longitud'] != null ? double.tryParse(o['longitud'].toString()) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final user = ref.watch(authStateProvider);
    final bool isAdmin = user != null && user.rol == 'admin';
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    final appBar = AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'PEDIDOS ALY',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'orders'),
      appBar: appBar,
      body: ordersAsync.when(
        data: (orders) {
          if (isWeb) {
            return _buildWebOrderTable(context, orders, isAdmin);
          } else {
            return _buildMobileOrderList(context, orders, isAdmin, ref);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildMobileOrderList(BuildContext context, List<Map<String, dynamic>> orders, bool isAdmin, WidgetRef ref) {
    if (orders.isEmpty) {
      return const Center(child: Text('No hay pedidos registrados.', style: TextStyle(color: AppTheme.textGray)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        return _orderCard(context, o, isAdmin, ref);
      },
    );
  }

  Widget _buildWebOrderTable(BuildContext context, List<Map<String, dynamic>> orders, bool isAdmin) {
    if (orders.isEmpty) {
      return const Center(child: Text('No hay pedidos registrados.', style: TextStyle(color: AppTheme.textGray)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.white.withOpacity(0.02)),
              dataRowHeight: 72,
              horizontalMargin: 24,
              columns: [
                DataColumn(label: Text('BOLETA', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('FECHA DE PEDIDO', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('PRODUCTOS', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('TOTAL', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('ESTADO', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('ACCIONES', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
              ],
              rows: orders.map((o) {
                final status = (o['estado'] ?? 'PENDIENTE').toString().toUpperCase();
                final isPending = status == 'PENDIENTE';
                final isTrackingEnabled = o['tracking_enabled'] == true;
                final id = o['id'] ?? '';

                Widget actionWidget;
                if (isAdmin) {
                  if (isPending) {
                    if (!isTrackingEnabled) {
                      actionWidget = ElevatedButton(
                        onPressed: () => _iniciarSeguimiento(context, id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(120, 36),
                        ),
                        child: const Text('HABILITAR DELIVERY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    } else {
                      actionWidget = ElevatedButton(
                        onPressed: () => _verMapa(context, o, id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(120, 36),
                        ),
                        child: const Text('VER MAPA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    }
                  } else {
                    actionWidget = const Text('Llegó a destino', style: TextStyle(color: AppTheme.textGray, fontSize: 11));
                  }
                } else {
                  if (isPending) {
                    if (isTrackingEnabled) {
                      actionWidget = ElevatedButton.icon(
                        onPressed: () => _verMapa(context, o, id),
                        icon: const Icon(Icons.map_rounded, size: 12, color: Colors.white),
                        label: const Text('RASTREAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(110, 36),
                        ),
                      );
                    } else {
                      actionWidget = const Text('En almacén Aly', style: TextStyle(color: AppTheme.textGray, fontSize: 11));
                    }
                  } else {
                    actionWidget = const Text('Entregado', style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold));
                  }
                }

                return DataRow(
                  cells: [
                    DataCell(Text(
                      o['nro_boleta'] ?? id.substring(0, min(id.length, 8)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                    DataCell(Text(
                      _formatDate(o['fecha_pedido'] ?? 'N/A'),
                      style: const TextStyle(color: AppTheme.textGray, fontSize: 12),
                    )),
                    DataCell(Text(
                      o['producto_nombre'] ?? 'Producto Desconocido',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    )),
                    DataCell(Text(
                      'S/ ${o['capital_invertido'] ?? '0.00'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending ? AppTheme.accentOrange.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPending ? AppTheme.accentOrange.withOpacity(0.3) : AppTheme.successGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isPending ? AppTheme.accentOrange : AppTheme.successGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
                    DataCell(actionWidget),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o, bool isAdmin, WidgetRef ref) {
    final String id = o['id'] ?? '';
    final String boleta = o['nro_boleta'] ?? id;
    final String date = _formatDate(o['fecha_pedido'] ?? 'N/A');
    final String product = o['producto_nombre'] ?? 'Producto Desconocido';
    final String price = 'S/ ${o['capital_invertido'] ?? '0.00'}';
    final String status = (o['estado'] ?? 'PENDIENTE').toString().toUpperCase();
    final bool isPending = status == 'PENDIENTE';
    final bool isTrackingEnabled = o['tracking_enabled'] == true;

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
                    boleta,
                    style: const TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: const TextStyle(color: AppTheme.textGray, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? AppTheme.accentOrange.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isPending ? AppTheme.accentOrange.withOpacity(0.2) : AppTheme.successGreen.withOpacity(0.2)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isPending ? AppTheme.accentOrange : AppTheme.successGreen,
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
                    const SizedBox(height: 2),
                    Text(product, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('INVERSIÓN', style: TextStyle(fontSize: 8, color: AppTheme.textGray, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                ],
              ),
            ],
          ),
          if (isPending) ...[
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isAdmin
                        ? (isTrackingEnabled ? '🚚 SEGUIMIENTO ACTIVO' : '🚚 NO INICIADO')
                        : (isTrackingEnabled ? '🟢 Camión en ruta a tu ubicación' : '⏳ Preparando materiales en almacén'),
                    style: TextStyle(
                      color: isTrackingEnabled ? AppTheme.successGreen : AppTheme.textGray,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isAdmin)
                  (!isTrackingEnabled
                      ? ElevatedButton(
                          onPressed: () => _iniciarSeguimiento(context, id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentOrange,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(120, 36),
                          ),
                          child: const Text('HABILITAR DELIVERY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : ElevatedButton(
                          onPressed: () => _verMapa(context, o, id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(120, 36),
                          ),
                          child: const Text('VER MAPA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ))
                else if (isTrackingEnabled)
                  ElevatedButton.icon(
                    onPressed: () => _verMapa(context, o, id),
                    icon: const Icon(Icons.map_rounded, size: 12, color: Colors.white),
                    label: const Text('RASTREAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(110, 36),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
