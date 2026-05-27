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
  bool _isGridView = false;
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

  static const Map<String, String> _imageHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
  };

  @override
  void initState() {
    super.initState();
    // Sincronizar el texto del controlador con el estado global de búsqueda
    _searchController.text = ref.read(searchQueryProvider);
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
    // Limpiar el estado de búsqueda y filtros al salir de la pantalla para evitar estados persistentes residuales
    Future.microtask(() {
      if (ref.context.mounted) {
        ref.read(searchQueryProvider.notifier).state = '';
        ref.read(selectedCategoryProvider.notifier).state = null;
        ref.read(soloDisponiblesProvider.notifier).state = false;
      }
    });
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
      floatingActionButton: widget.userRole == 'admin'
          ? FloatingActionButton(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
              onPressed: () => _openAddEditProductDialog(),
            )
          : null,
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
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'Ver como lista' : 'Ver como cuadrícula',
          ),
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
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: productos.length,
        itemBuilder: (context, index) {
          final producto = productos[index];
          return _buildGridCard(producto, index);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: productos.length,
        itemBuilder: (context, index) {
          final producto = productos[index];
          return _buildLargeProductCard(producto, index);
        },
      );
    }
  }

  String _getProductImage(CatalogoProducto producto) {
    if (producto.imagenUrl != null && producto.imagenUrl!.trim().isNotEmpty) {
      return producto.imagenUrl!;
    }
    // URLs de Unsplash dinámicas según categoría para un diseño premium inmediato
    switch (producto.categoria) {
      case 'Herramientas Manuales':
        return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop';
      case 'Herramientas Eléctricas':
        return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop';
      case 'Materiales de Construcción':
        return 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop';
      case 'Seguridad Industrial':
        return 'https://images.unsplash.com/photo-1598501479109-22a4625cf6e7?w=500&auto=format&fit=crop';
      case 'Fijaciones y Tornillería':
        return 'https://images.unsplash.com/photo-1530124560072-aae8d7db1eb6?w=500&auto=format&fit=crop';
      case 'Abrasivos y Consumibles':
        return 'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?w=500&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop';
    }
  }

  Widget _buildGridCard(CatalogoProducto producto, int index) {
    final color = _categoryColors[producto.categoria] ?? AppTheme.accentOrange;
    final imageUrl = _getProductImage(producto);

    return AnimatedContainer(
      duration: Duration(milliseconds: 100 + (index * 20)),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetail(producto),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen del producto (arriba)
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          headers: _imageHeaders,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.white.withOpacity(0.03),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: color.withOpacity(0.1),
                            child: Center(
                              child: Icon(
                                _categoryIcons[producto.categoria] ?? Icons.category_rounded,
                                color: color,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (producto.disponible ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            producto.disponible ? 'Disponible' : 'Agotado',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Detalles (abajo)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.subcategoria.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        producto.marca,
                        style: const TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'S/ ${producto.precioUnitario.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'May: S/${producto.precioMayorista.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'x ${producto.unidad}',
                            style: const TextStyle(
                              color: AppTheme.textGray,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeProductCard(CatalogoProducto producto, int index) {
    final color = _categoryColors[producto.categoria] ?? AppTheme.accentOrange;
    final imageUrl = _getProductImage(producto);

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
            height: 120, // Altura fija para evitar el IntrinsicHeight y desbordamientos en Web
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Imagen lateral
                  Container(
                    width: 110,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white.withOpacity(0.04)),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          headers: _imageHeaders,
                          width: 110,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.white.withOpacity(0.03),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: color.withOpacity(0.1),
                            child: Center(
                              child: Icon(
                                _categoryIcons[producto.categoria] ?? Icons.category_rounded,
                                color: color,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        if (!producto.disponible)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: const Center(
                              child: Text(
                                'AGOTADO',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.errorRed,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Detalles a la derecha
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${producto.categoria} · ${producto.subcategoria}'.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 7.5,
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
                              Text(
                                producto.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                producto.marca,
                                style: const TextStyle(
                                  color: AppTheme.textGray,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'S/ ${producto.precioUnitario.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Mayorista: S/ ${producto.precioMayorista.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.successGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'x ${producto.unidad}',
                                style: const TextStyle(
                                  color: AppTheme.textGray,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProductDetail(CatalogoProducto producto) {
    final color = _categoryColors[producto.categoria] ?? AppTheme.accentOrange;
    final icon = _categoryIcons[producto.categoria] ?? Icons.category_rounded;
    final imageUrl = _getProductImage(producto);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
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
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          headers: _imageHeaders,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
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
                        ),
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
                  _detailRow('MARCA', producto.marca),
                  _detailRow('SKU', producto.codigoSku ?? 'N/A'),
                  _detailRow('UNIDAD', producto.unidad.toUpperCase()),
                  _detailRow('STOCK MÍNIMO', '${producto.stockMinimo} unidades'),
                  const SizedBox(height: 16),
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
                  if (producto.caracteristicas.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'CARACTERÍSTICAS TÉCNICAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: producto.caracteristicas.map((char) {
                        final parts = char.split(':');
                        final name = parts.first.trim();
                        final val = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 5, color: AppTheme.accentOrange),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$name:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textGray,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  val,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                  if (widget.userRole == 'admin') ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorRed,
                              side: const BorderSide(color: AppTheme.errorRed),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.delete_forever_rounded, size: 18),
                            label: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteProduct(producto);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('EDITAR', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(context);
                              _openAddEditProductDialog(producto);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAddEditProductDialog([CatalogoProducto? producto]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddEditProductDialog(
        producto: producto,
        onSaved: () {
          // El streamprovider de Riverpod recarga automáticamente desde Firestore
        },
      ),
    );
  }

  void _confirmDeleteProduct(CatalogoProducto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Eliminar Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Está seguro de que desea eliminar "${producto.nombre}" del catálogo?', style: const TextStyle(color: AppTheme.textGray)),
        actions: [
          TextButton(
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(firestoreServiceProvider).deleteCatalogoProducto(producto.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${producto.nombre}" eliminado del catálogo.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
          ),
        ],
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

class _AddEditProductDialog extends ConsumerStatefulWidget {
  final CatalogoProducto? producto;
  final VoidCallback onSaved;
  const _AddEditProductDialog({this.producto, required this.onSaved});

  @override
  ConsumerState<_AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends ConsumerState<_AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _subcatCtrl;
  late TextEditingController _marcaCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _unidadCtrl;
  late TextEditingController _stockMinCtrl;
  late TextEditingController _precioUnitCtrl;
  late TextEditingController _precioMayCtrl;
  late TextEditingController _imagenUrlCtrl;
  late TextEditingController _tagsCtrl;
  
  late String _categoria;
  late bool _disponible;
  late List<String> _caracteristicas;
  
  final _newCharKeyCtrl = TextEditingController();
  final _newCharValCtrl = TextEditingController();

  static const List<String> _categorias = [
    'Herramientas Manuales',
    'Herramientas Eléctricas',
    'Materiales de Construcción',
    'Seguridad Industrial',
    'Fijaciones y Tornillería',
    'Abrasivos y Consumibles'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descCtrl = TextEditingController(text: p?.descripcion ?? '');
    _subcatCtrl = TextEditingController(text: p?.subcategoria ?? '');
    _marcaCtrl = TextEditingController(text: p?.marca ?? '');
    _skuCtrl = TextEditingController(text: p?.codigoSku ?? '');
    _unidadCtrl = TextEditingController(text: p?.unidad ?? 'unidad');
    _stockMinCtrl = TextEditingController(text: (p?.stockMinimo ?? 5).toString());
    _precioUnitCtrl = TextEditingController(text: p?.precioUnitario != null ? p!.precioUnitario.toStringAsFixed(2) : '');
    _precioMayCtrl = TextEditingController(text: p?.precioMayorista != null ? p!.precioMayorista.toStringAsFixed(2) : '');
    _imagenUrlCtrl = TextEditingController(text: p?.imagenUrl ?? '');
    _tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    
    _categoria = p?.categoria ?? _categorias.first;
    _disponible = p?.disponible ?? true;
    _caracteristicas = List<String>.from(p?.caracteristicas ?? []);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _subcatCtrl.dispose();
    _marcaCtrl.dispose();
    _skuCtrl.dispose();
    _unidadCtrl.dispose();
    _stockMinCtrl.dispose();
    _precioUnitCtrl.dispose();
    _precioMayCtrl.dispose();
    _imagenUrlCtrl.dispose();
    _tagsCtrl.dispose();
    _newCharKeyCtrl.dispose();
    _newCharValCtrl.dispose();
    super.dispose();
  }

  void _addCaracteristica() {
    final key = _newCharKeyCtrl.text.trim();
    final val = _newCharValCtrl.text.trim();
    if (key.isNotEmpty && val.isNotEmpty) {
      setState(() {
        _caracteristicas.add('$key: $val');
        _newCharKeyCtrl.clear();
        _newCharValCtrl.clear();
      });
    }
  }

  void _removeCaracteristica(int index) {
    setState(() {
      _caracteristicas.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final double precioUnit = double.tryParse(_precioUnitCtrl.text) ?? 0.0;
    final double precioMay = double.tryParse(_precioMayCtrl.text) ?? 0.0;
    final int stockMin = int.tryParse(_stockMinCtrl.text) ?? 5;
    
    final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final data = {
      'nombre': _nombreCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'categoria': _categoria,
      'subcategoria': _subcatCtrl.text.trim(),
      'marca': _marcaCtrl.text.trim(),
      'codigo_sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      'unidad': _unidadCtrl.text.trim(),
      'stock_minimo': stockMin,
      'precio_unitario': precioUnit,
      'precio_mayorista': precioMay,
      'imagen_url': _imagenUrlCtrl.text.trim().isEmpty ? null : _imagenUrlCtrl.text.trim(),
      'disponible': _disponible,
      'tags': tags,
      'caracteristicas': _caracteristicas,
      'nombre_busqueda': _normalizarText(_nombreCtrl.text),
      'marca_busqueda': _normalizarText(_marcaCtrl.text),
      'categoria_busqueda': _normalizarText(_categoria),
    };

    try {
      final service = ref.read(firestoreServiceProvider);
      if (widget.producto == null) {
        await service.createCatalogoProducto(data);
      } else {
        await service.updateCatalogoProducto(widget.producto!.id, data);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.producto == null ? 'Producto creado correctamente.' : 'Producto actualizado correctamente.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _normalizarText(String text) {
    String r = text.toLowerCase().trim();
    const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.producto != null;
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textGray),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(_nombreCtrl, 'Nombre del Producto', 'Ej. Rotomartillo SDS Max 1500W', required: true),
                      const SizedBox(height: 12),
                      const Text(
                        'Categoría',
                        style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _categoria,
                        dropdownColor: AppTheme.surfaceDark,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.accentOrange),
                          ),
                        ),
                        items: _categorias.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _categoria = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_subcatCtrl, 'Subcategoría', 'Ej. Rotomartillos', required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_marcaCtrl, 'Marca', 'Ej. DeWalt', required: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_skuCtrl, 'Código SKU', 'Ej. HE-ROT-008')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_unidadCtrl, 'Unidad de Medida', 'Ej. unidad', required: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_precioUnitCtrl, 'Precio Unitario (S/)', '0.00', number: true, required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_precioMayCtrl, 'Precio Mayorista (S/)', '0.00', number: true, required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_stockMinCtrl, 'Stock Mínimo', '5', integer: true, required: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_imagenUrlCtrl, 'URL de la Imagen', 'https://images.unsplash.com/...'),
                      const SizedBox(height: 12),
                      _buildTextField(_tagsCtrl, 'Etiquetas (separadas por comas)', 'herramientas, rotomartillo, dewalt'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disponibilidad',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Indica si hay stock disponible para la venta',
                                style: TextStyle(color: AppTheme.textGray, fontSize: 10),
                              ),
                            ],
                          ),
                          Switch(
                            value: _disponible,
                            onChanged: (val) => setState(() => _disponible = val),
                            activeColor: AppTheme.accentOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'CARACTERÍSTICAS TÉCNICAS',
                        style: TextStyle(color: AppTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      if (_caracteristicas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No se han agregado características técnicas.',
                            style: TextStyle(color: AppTheme.textGray, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _caracteristicas.length,
                          itemBuilder: (context, index) {
                            final char = _caracteristicas[index];
                            final parts = char.split(':');
                            final name = parts.first.trim();
                            final val = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 12, color: Colors.white),
                                        children: [
                                          TextSpan(text: '$name: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textGray)),
                                          TextSpan(text: val),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 16),
                                    onPressed: () => _removeCaracteristica(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newCharKeyCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: _inputDecoration('Propiedad', 'Ej. Potencia'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _newCharValCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: _inputDecoration('Valor', 'Ej. 1500W'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accentOrange, size: 28),
                            onPressed: _addCaracteristica,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _save,
                    child: const Text(
                      'GUARDAR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool required = false, bool number = false, bool integer = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: number || integer ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: (val) {
            if (required && (val == null || val.trim().isEmpty)) {
              return 'Este campo es obligatorio';
            }
            if (number && val != null && val.isNotEmpty && double.tryParse(val) == null) {
              return 'Número inválido';
            }
            if (integer && val != null && val.isNotEmpty && int.tryParse(val) == null) {
              return 'Número entero inválido';
            }
            return null;
          },
          decoration: _inputDecoration('', hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: const TextStyle(color: AppTheme.textGray, fontSize: 12),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accentOrange)),
    );
  }
}
