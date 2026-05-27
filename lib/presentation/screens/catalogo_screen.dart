import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/catalogo_provider.dart';
import 'dart:async';

class CatalogoScreen extends ConsumerStatefulWidget {
  final String userRole;
  const CatalogoScreen({super.key, required this.userRole});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showFilters = false;
  late AnimationController _filterAnimController;
  late Animation<double> _filterAnimation;

  // Iconos de categoría para el UI
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

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _filterAnimController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _filterAnimController.forward();
      } else {
        _filterAnimController.reverse();
      }
    });
  }

  void _clearFilters() {
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = null;
    ref.read(soloDisponiblesProvider.notifier).state = false;
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final totalCount = ref.watch(totalCatalogoProvider);
    final resultCount = ref.watch(searchResultCountProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CATÁLOGO DE PRODUCTOS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5),
            ),
            Text(
              query.isEmpty && selectedCategory == null
                  ? '$totalCount productos disponibles'
                  : '$resultCount de $totalCount resultados',
              style: const TextStyle(color: AppTheme.textGray, fontSize: 10, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: selectedCategory != null || query.isNotEmpty,
              backgroundColor: AppTheme.accentOrange,
              smallSize: 8,
              child: Icon(
                _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                size: 22,
              ),
            ),
            onPressed: _toggleFilters,
          ),
          if (query.isNotEmpty || selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded, size: 22),
              onPressed: _clearFilters,
              tooltip: 'Limpiar filtros',
            ),
        ],
      ),
      body: Column(
        children: [
          // === BARRA DE BÚSQUEDA ===
          _buildSearchBar(),
          // === FILTROS EXPANDIBLES ===
          SizeTransition(
            sizeFactor: _filterAnimation,
            child: _buildFilterSection(),
          ),
          // === CHIPS DE CATEGORÍA RÁPIDOS ===
          _buildCategoryChips(),
          // === LISTA DE RESULTADOS ===
          Expanded(
            child: results.isEmpty
                ? _buildEmptyState(query)
                : _buildProductGrid(results),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: '🔍 Buscar por nombre, marca, categoría...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 13,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search_rounded, color: AppTheme.accentOrange, size: 22),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textGray),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final soloDisponibles = ref.watch(soloDisponiblesProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentOrange.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FILTROS AVANZADOS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppTheme.accentOrange,
                ),
              ),
              Switch(
                value: soloDisponibles,
                onChanged: (v) => ref.read(soloDisponiblesProvider.notifier).state = v,
                activeColor: AppTheme.accentOrange,
              ),
            ],
          ),
          Text(
            soloDisponibles ? 'Solo productos disponibles' : 'Todos los productos',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categorias = ref.watch(categoriasProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    if (categorias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final isSelected = cat == selectedCategory;
          final color = _categoryColors[cat] ?? AppTheme.accentOrange;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textGray,
                    letterSpacing: 0.3,
                  ),
                ),
                avatar: Icon(
                  _categoryIcons[cat] ?? Icons.category_rounded,
                  size: 14,
                  color: isSelected ? Colors.white : color,
                ),
                backgroundColor: AppTheme.surfaceDark,
                selectedColor: color.withOpacity(0.3),
                side: BorderSide(
                  color: isSelected ? color : Colors.white.withOpacity(0.06),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (selected) {
                  ref.read(selectedCategoryProvider.notifier).state = selected ? cat : null;
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            query.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 64,
            color: AppTheme.textGray.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty ? 'Sin resultados para "$query"' : 'El catálogo está vacío',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            query.isNotEmpty
                ? 'Intenta con otra búsqueda o limpia los filtros'
                : 'Los productos se cargarán automáticamente',
            style: TextStyle(color: AppTheme.textGray.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<CatalogoProducto> productos) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        return _buildProductCard(producto, index);
      },
    );
  }

  Widget _buildProductCard(CatalogoProducto producto, int index) {
    final color = _categoryColors[producto.categoria] ?? AppTheme.accentOrange;
    final icon = _categoryIcons[producto.categoria] ?? Icons.category_rounded;

    return AnimatedContainer(
      duration: Duration(milliseconds: 100 + (index * 30)),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetail(producto),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                // Ícono del producto
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                // Información del producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categoría tag
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              producto.subcategoria.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (producto.disponible)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Nombre
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Marca
                      Text(
                        producto.marca,
                        style: const TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Precio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'S/ ${producto.precioUnitario.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'x ${producto.unidad}',
                      style: const TextStyle(
                        color: AppTheme.textGray,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'May: S/${producto.precioMayorista.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProductDetail(CatalogoProducto producto) {
    final color = _categoryColors[producto.categoria] ?? AppTheme.accentOrange;
    final icon = _categoryIcons[producto.categoria] ?? Icons.category_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Icono grande + categoría
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${producto.categoria} · ${producto.subcategoria}'.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              producto.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Marca
                  _detailRow('MARCA', producto.marca),
                  _detailRow('SKU', producto.codigoSku ?? 'N/A'),
                  _detailRow('UNIDAD', producto.unidad.toUpperCase()),
                  _detailRow('STOCK MÍNIMO', '${producto.stockMinimo} unidades'),
                  const SizedBox(height: 16),
                  // Precios
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentOrange.withOpacity(0.08),
                          AppTheme.accentOrange.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentOrange.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _priceColumn('UNITARIO', 'S/ ${producto.precioUnitario.toStringAsFixed(2)}', Colors.white),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                        _priceColumn('MAYORISTA', 'S/ ${producto.precioMayorista.toStringAsFixed(2)}', AppTheme.successGreen),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Descripción
                  const Text(
                    'DESCRIPCIÓN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    producto.descripcion,
                    style: const TextStyle(
                      color: AppTheme.textGray,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tags
                  if (producto.tags.isNotEmpty) ...[
                    const Text(
                      'ETIQUETAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: producto.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textGray),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Estado
                  Row(
                    children: [
                      Icon(
                        producto.disponible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: producto.disponible ? AppTheme.successGreen : AppTheme.errorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        producto.disponible ? 'Disponible en inventario' : 'No disponible',
                        style: TextStyle(
                          color: producto.disponible ? AppTheme.successGreen : AppTheme.errorRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textGray,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceColumn(String label, String price, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          price,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
