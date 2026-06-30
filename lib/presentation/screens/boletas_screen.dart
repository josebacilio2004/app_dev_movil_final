import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/catalogo_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/connection_status_indicator.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:intl/intl.dart';

class BoletasScreen extends ConsumerStatefulWidget {
  const BoletasScreen({super.key});

  @override
  ConsumerState<BoletasScreen> createState() => _BoletasScreenState();
}

class _BoletasScreenState extends ConsumerState<BoletasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  bool _showFilters = false;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  String _selectedCategory = 'Todas';

  final List<String> _categories = [
    'Todas',
    'Herramientas Manuales',
    'Herramientas Eléctricas',
    'Materiales de Construcción',
    'EPP y Seguridad',
    'Pinturas y Acabados',
    'Electricidad y Plomería'
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const SizedBox.shrink();

    final firestoreService = ref.watch(firestoreServiceProvider);
    final appBar = AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'MIS BOLETAS / FACTURAS',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
      actions: const [
        ConnectionStatusIndicator(),
        SizedBox(width: 16),
      ],
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
    );

    final mainContent = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.pedidosStream(compradorId: user.id, role: user.rol),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar facturas: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];
          
          // Filtrar órdenes por rol del usuario
          List<Map<String, dynamic>> userOrders = [];
          if (user.rol.toLowerCase() == 'comprador') {
            userOrders = allOrders.where((o) => o['comprador_id'] == user.id).toList();
          } else {
            // Admin y Operador ven todas
            userOrders = allOrders;
          }

          // Aplicar filtro de búsqueda (por ID de boleta o nombre del comprador)
          if (_searchQuery.isNotEmpty) {
            userOrders = userOrders.where((o) {
              final id = (o['id'] ?? '').toString().toLowerCase();
              final name = (o['comprador_nombre'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return id.contains(query) || name.contains(query);
            }).toList();
          }

          // Aplicar filtros avanzados
          if (_startDate != null) {
            userOrders = userOrders.where((o) {
              final dateRaw = o['fecha_pedido'];
              if (dateRaw == null) return false;
              final date = DateTime.tryParse(dateRaw.toString());
              if (date == null) return false;
              final orderMidnight = DateTime(date.year, date.month, date.day);
              final startMidnight = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              return orderMidnight.isAtSameMomentAs(startMidnight) || orderMidnight.isAfter(startMidnight);
            }).toList();
          }

          if (_endDate != null) {
            userOrders = userOrders.where((o) {
              final dateRaw = o['fecha_pedido'];
              if (dateRaw == null) return false;
              final date = DateTime.tryParse(dateRaw.toString());
              if (date == null) return false;
              final orderMidnight = DateTime(date.year, date.month, date.day);
              final endMidnight = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
              return orderMidnight.isAtSameMomentAs(endMidnight) || orderMidnight.isBefore(endMidnight);
            }).toList();
          }

          if (_minAmount != null) {
            userOrders = userOrders.where((o) {
              final total = (o['capital_invertido'] as num?)?.toDouble() ?? 0.0;
              return total >= _minAmount!;
            }).toList();
          }

          if (_maxAmount != null) {
            userOrders = userOrders.where((o) {
              final total = (o['capital_invertido'] as num?)?.toDouble() ?? 0.0;
              return total <= _maxAmount!;
            }).toList();
          }

          if (_selectedCategory != 'Todas') {
            final catalogAsync = ref.watch(catalogoStreamProvider);
            final allCatalogProducts = catalogAsync.value ?? [];
            userOrders = userOrders.where((o) {
              final items = o['items'] as List<dynamic>? ?? [];
              return items.any((item) {
                final itemCat = item['categoria']?.toString() ?? '';
                if (itemCat.isNotEmpty) {
                  return itemCat.toLowerCase() == _selectedCategory.toLowerCase();
                }
                final prodId = item['producto_id']?.toString() ?? '';
                final matchingProd = allCatalogProducts.firstWhere(
                  (p) => p.id == prodId,
                  orElse: () => CatalogoProducto(id: '', nombre: '', descripcion: '', categoria: '', subcategoria: '', precioUnitario: 0, precioMayorista: 0, disponible: false, unidad: '', marca: '')
                );
                return matchingProd.categoria.toLowerCase() == _selectedCategory.toLowerCase();
              });
            }).toList();
          }

          final bool isWeb = MediaQuery.of(context).size.width >= 900;
          return Column(
            children: [
              // Barra de Búsqueda
              _buildSearchBar(user.rol.toLowerCase()),
              
              // Panel de Filtros Avanzados
              _buildAdvancedFiltersPanel(),
              
              Expanded(
                child: isWeb
                    ? _buildWebInvoiceTable(userOrders)
                    : (userOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: userOrders.length,
                            itemBuilder: (context, index) {
                              final o = userOrders[index];
                              return _buildInvoiceCard(o);
                            },
                          )),
              ),
            ],
          );
        },
      ),
    ),
  );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'invoices'),
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _buildWebInvoiceTable(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                DataColumn(label: Text('FECHA', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('ADQUIRIDO POR', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('ITEMS', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('TOTAL PAGADO', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                DataColumn(label: Text('ACCIONES', style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
              ],
              rows: orders.map((o) {
                final docId = (o['nro_boleta'] ?? o['id'] ?? 'BOL-XXXX').toString();
                final cleanId = docId.startsWith('B001-') || docId.startsWith('BOL-')
                    ? docId
                    : (docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase());
                final fechaRaw = o['fecha_pedido'] ?? DateTime.now().toIso8601String();
                
                DateTime parsedDate;
                try {
                  parsedDate = DateTime.parse(fechaRaw);
                } catch (_) {
                  parsedDate = DateTime.now();
                }
                
                final formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(parsedDate);
                final total = (o['capital_invertido'] as num?)?.toDouble() ?? 0.0;
                final compradorNombre = o['comprador_nombre'] ?? 'Cliente General';
                final itemsCount = (o['cantidad'] as num?)?.toInt() ?? 0;
                final itemsList = o['items'] as List<dynamic>? ?? [];

                return DataRow(
                  cells: [
                    DataCell(Text(
                      cleanId.startsWith('B001-') || cleanId.startsWith('BOL-') ? cleanId : 'BOL-$cleanId',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                    DataCell(Text(
                      formattedDate,
                      style: const TextStyle(color: AppTheme.textGray, fontSize: 12),
                    )),
                    DataCell(Text(
                      compradorNombre,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    )),
                    DataCell(Text(
                      '$itemsCount un.',
                      style: const TextStyle(color: AppTheme.textGray, fontSize: 13),
                    )),
                    DataCell(Text(
                      'S/ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                    DataCell(ElevatedButton.icon(
                      onPressed: () => _showInvoiceDetails(context, docId, compradorNombre, formattedDate, total, itemsList),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: const Text('DETALLE / PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                        foregroundColor: AppTheme.accentOrange,
                        side: const BorderSide(color: AppTheme.accentOrange, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(String role) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: AppTheme.surfaceDark.withOpacity(0.3),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: role == 'comprador' 
                    ? 'Buscar por ID de Boleta...' 
                    : 'Buscar por ID o Comprador...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGray),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textGray),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceDark,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _showFilters ? AppTheme.accentOrange.withOpacity(0.2) : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showFilters ? AppTheme.accentOrange : Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.filter_alt_rounded,
                color: _showFilters ? AppTheme.accentOrange : AppTheme.textGray,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersPanel() {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FILTRAR POR RANGO DE FECHAS',
              style: GoogleFonts.outfit(
                color: AppTheme.textGray,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                        locale: const Locale('es', 'PE'),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 14),
                    label: Text(
                      _startDate == null 
                          ? 'Fecha Inicio' 
                          : DateFormat('dd/MM/yyyy').format(_startDate!),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                        locale: const Locale('es', 'PE'),
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 14),
                    label: Text(
                      _endDate == null 
                          ? 'Fecha Fin' 
                          : DateFormat('dd/MM/yyyy').format(_endDate!),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'FILTRAR POR RANGO DE MONTOS (S/)',
              style: GoogleFonts.outfit(
                color: AppTheme.textGray,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Monto Mínimo',
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _minAmount = double.tryParse(val);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Monto Máximo',
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _maxAmount = double.tryParse(val);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'FILTRAR POR CATEGORÍA DE PRODUCTO',
              style: GoogleFonts.outfit(
                color: AppTheme.textGray,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: AppTheme.surfaceDark,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentOrange),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                  items: _categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _minAmount = null;
                      _maxAmount = null;
                      _selectedCategory = 'Todas';
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accentOrange),
                  label: Text(
                    'RESTABLECER FILTROS',
                    style: GoogleFonts.outfit(
                      color: AppTheme.accentOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      crossFadeState: _showFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.textGray,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? 'No hay comprobantes de pago' 
                : 'No se encontraron resultados',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las boletas aparecerán aquí después de realizar compras.',
            style: TextStyle(color: AppTheme.textGray, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> o) {
    final docId = (o['nro_boleta'] ?? o['id'] ?? 'BOL-XXXX').toString();
    final cleanId = docId.startsWith('B001-') || docId.startsWith('BOL-')
        ? docId
        : (docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase());
    final fechaRaw = o['fecha_pedido'] ?? DateTime.now().toIso8601String();
    
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(fechaRaw);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(parsedDate);
    final total = (o['capital_invertido'] as num?)?.toDouble() ?? 0.0;
    final compradorNombre = o['comprador_nombre'] ?? 'Cliente General';
    final itemsCount = (o['cantidad'] as num?)?.toInt() ?? 0;
    final itemsList = o['items'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOLETA: BOL-$cleanId',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppTheme.accentOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: AppTheme.textGray, fontSize: 10),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'PAGADO',
                    style: TextStyle(
                      color: AppTheme.successGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADQUIRIDO POR',
                        style: TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        compradorNombre,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL PAGADO',
                      style: TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/ ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$itemsCount unidades de productos',
                    style: const TextStyle(color: AppTheme.textGray, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showInvoiceDetails(context, docId, compradorNombre, formattedDate, total, itemsList),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                  label: const Text('VER DETALLE / PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                    foregroundColor: AppTheme.accentOrange,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.accentOrange, width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceDetails(
    BuildContext context,
    String docId,
    String compradorNombre,
    String dateStr,
    double total,
    List<dynamic> items,
  ) {
    final cleanId = docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DETALLE DE COMPROBANTE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textGray),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                
                // Info de cabecera
                _detailRow('Nro. Boleta', 'BOL-$cleanId'),
                _detailRow('Cliente', compradorNombre),
                _detailRow('Fecha / Hora', dateStr),
                _detailRow('Método de Pago', 'Tarjeta Digital'),
                
                const SizedBox(height: 16),
                const Text(
                  'DETALLE DE ARTÍCULOS',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                
                // Lista de Items
                ...items.map((item) {
                  final name = item['nombre'] ?? 'Producto';
                  final qty = item['cantidad'] ?? 1;
                  final price = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                  final sub = qty * price;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name (x$qty)',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'S/ ${sub.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }),
                
                const Divider(color: Colors.white10),
                _detailRow(
                  'Monto Total',
                  'S/ ${total.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor: AppTheme.successGreen,
                ),
                
                const SizedBox(height: 32),
                
                // Botón para exportar PDF
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportPdf(docId, compradorNombre, dateStr, total, items);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('IMPRIMIR / EXPORTAR BOLETA PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _sharePdf(docId, compradorNombre, dateStr, total, items);
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('COMPARTIR POR REDES SOCIALES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textGray, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Generador de PDF
  Future<pw.Document> _buildPdfDocument(
    String docId,
    String compradorNombre,
    String dateStr,
    double total,
    List<dynamic> items,
  ) async {
    final pdf = pw.Document();
    final cleanId = docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase();
    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/logo-validado.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar logo para PDF: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(right: 12),
                            width: 50,
                            height: 50,
                            child: pw.Image(logoImage),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'COMERCIALIZADORA ALY',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange,
                              ),
                            ),
                            pw.Text('Herramientas y Materiales de Construccion'),
                            pw.Text('RUC: 10432247657'),
                            pw.Text('Direccion: Calle Real 456, Huancayo'),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'BOLETA ELECTRONICA',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              pw.Text(
                                'BOL-$cleanId',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.orange,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Client Info
                pw.Text(
                  'DATOS DEL CLIENTE',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.orange,
                  ),
                ),
                pw.Divider(color: PdfColors.orange, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Nombre: $compradorNombre'),
                    pw.Text('Fecha: $dateStr'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Metodo Pago: Tarjeta de Credito/Debito'),
                    pw.Text('ID Transaccion: $docId'),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Items Table
                pw.Text(
                  'DETALLE DE COMPRA',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.orange,
                  ),
                ),
                pw.Divider(color: PdfColors.orange, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('P. Unitario', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Subtotal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      final name = item['nombre'] ?? 'Producto';
                      final qty = item['cantidad'] ?? 1;
                      final price = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                      final sub = qty * price;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$qty unidades', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('S/ ${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('S/ ${sub.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('Subtotal: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('S/ ${(total / 1.18).toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text('I.G.V. (18%): ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('S/ ${(total - (total / 1.18)).toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Divider(color: PdfColors.grey),
                        pw.Row(
                          children: [
                            pw.Text('Total Pagado: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                            pw.Text('S/ ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                
                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Gracias por comprar en Comercializadora Aly!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('Representacion impresa de la Boleta Electronica.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _exportPdf(
    String docId,
    String compradorNombre,
    String dateStr,
    double total,
    List<dynamic> items,
  ) async {
    try {
      final doc = await _buildPdfDocument(docId, compradorNombre, dateStr, total, items);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Boleta_Aly_BOL_${docId.substring(0, min(8, docId.length)).toUpperCase()}.pdf',
      );
    } catch (e) {
      debugPrint('Error al imprimir/guardar PDF: $e');
    }
  }

  Future<void> _sharePdf(
    String docId,
    String compradorNombre,
    String dateStr,
    double total,
    List<dynamic> items,
  ) async {
    try {
      final doc = await _buildPdfDocument(docId, compradorNombre, dateStr, total, items);
      final pdfBytes = await doc.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Boleta_Aly_BOL_${docId.substring(0, min(8, docId.length)).toUpperCase()}.pdf',
      );
    } catch (e) {
      debugPrint('Error al compartir PDF: $e');
    }
  }
}
