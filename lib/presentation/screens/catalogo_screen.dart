import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/catalogo_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/cart_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/cart_screen.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/google_drive_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';

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

  // Búsqueda por Voz
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  // Estado Offline
  bool _isOffline = false;
  Timer? _connectivityTimer;

  // Sensores (Shake to Refresh)
  StreamSubscription? _accelerometerSubscription;
  DateTime? _lastShakeTime;

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

  Widget _buildProductImageWidget(String imageUrl, String categoria, {double? width, double? height, BoxFit fit = BoxFit.cover, double placeholderIconSize = 28}) {
    final color = _categoryColors[categoria] ?? AppTheme.accentOrange;
    
    if (imageUrl.trim().isEmpty) {
      return Container(
        color: color.withOpacity(0.1),
        child: Center(
          child: Icon(
            _categoryIcons[categoria] ?? Icons.category_rounded,
            color: color,
            size: placeholderIconSize,
          ),
        ),
      );
    }
    
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: color.withOpacity(0.1),
            child: Center(
              child: Icon(
                _categoryIcons[categoria] ?? Icons.category_rounded,
                color: color,
                size: placeholderIconSize,
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decodificando base64: $e');
      }
    }
    
    final int? cWidth = (width != null && width.isFinite && width > 0) ? (width * 2.0).toInt() : 300;
    final int? cHeight = (height != null && height.isFinite && height > 0) ? (height * 2.0).toInt() : 300;

    return Image.network(
      imageUrl,
      headers: (imageUrl.contains('google') || imageUrl.contains('drive')) ? _imageHeaders : null,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cWidth,
      cacheHeight: cHeight,
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
            _categoryIcons[categoria] ?? Icons.category_rounded,
            color: color,
            size: placeholderIconSize,
          ),
        ),
      ),
    );
  }

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

    // Inicializar reconocedor de voz
    _initSpeech();

    // Iniciar chequeo de conectividad periódico (cada 8 segundos)
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 8), (_) => _checkConnectivity());

    // Configurar Shake to Refresh mediante acelerómetro
    _setupShakeDetection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _filterAnimController.dispose();
    _connectivityTimer?.cancel();
    _speechToText.stop();
    _accelerometerSubscription?.cancel();
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

  void _setupShakeDetection() {
    if (kIsWeb) return;
    
    try {
      const double shakeThreshold = 12.5;
      _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        gForce = (gForce - 9.8).abs();
        
        if (gForce > shakeThreshold) {
          final now = DateTime.now();
          if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 2)) {
            _lastShakeTime = now;
            _onShakeDetected();
          }
        }
      });
    } catch (e) {
      debugPrint('No se pudo inicializar Shake-to-Refresh: $e');
    }
  }

  void _onShakeDetected() {
    HapticFeedback.mediumImpact();
    ref.invalidate(catalogoStreamProvider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: AppTheme.accentOrange),
              const SizedBox(width: 12),
              Text(
                '🔄 ¡Dispositivo sacudido! Recargando stock Aly...',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppTheme.surfaceDark,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.accentOrange.withOpacity(0.3)),
          ),
        ),
      );
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('🎙️ Speech Status: $status');
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('🎙️ Speech Error: $error');
          setState(() => _isListening = false);
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('🎙️ Speech init failed: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      
      showDialog(
        context: context,
        builder: (context) {
          final voiceMockController = TextEditingController();
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Row(
              children: [
                Icon(Icons.mic_rounded, color: AppTheme.accentOrange),
                SizedBox(width: 10),
                Text('Búsqueda por Voz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El reconocimiento de voz del sistema no está disponible en este navegador o emulador. Puedes simular tu voz escribiendo lo que dirías:',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: voiceMockController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Ingresa tu comando de voz...',
                    hintText: 'Ej. martillo, cemento, casco...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = voiceMockController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _searchController.text = text;
                    });
                    ref.read(searchQueryProvider.notifier).state = text;
                  }
                  Navigator.pop(context);
                },
                child: const Text('BUSCAR'),
              ),
            ],
          );
        },
      );
      return;
    }
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _searchController.text = result.recognizedWords;
        });
        ref.read(searchQueryProvider.notifier).state = result.recognizedWords;
      },
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _checkConnectivity() async {
    if (kIsWeb) {
      if (mounted && _isOffline) {
        setState(() => _isOffline = false);
      }
      return;
    }
    try {
      final response = await Dio().get('https://clients3.google.com/generate_204').timeout(const Duration(seconds: 4));
      if (response.statusCode == 204) {
        if (mounted && _isOffline) {
          setState(() => _isOffline = false);
        }
      }
    } catch (_) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    }
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
    ref.read(selectedBrandProvider.notifier).state = null;
    ref.read(soloDisponiblesProvider.notifier).state = false;
    ref.read(precioMinProvider.notifier).state = 0.0;
    ref.read(precioMaxProvider.notifier).state = 999999.0;
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final totalCount = ref.watch(totalCatalogoProvider);
    final resultCount = ref.watch(searchResultCountProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedBrand = ref.watch(selectedBrandProvider);
    final precioMin = ref.watch(precioMinProvider);
    final precioMax = ref.watch(precioMaxProvider);
    final isFilterActive = query.isNotEmpty || selectedCategory != null || selectedBrand != null || precioMin > 0 || precioMax < 999999;
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    final appBar = AppBar(
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
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
            label: Text(
              '${ref.watch(cartCountProvider)}',
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
            isLabelVisible: ref.watch(cartCountProvider) > 0,
            backgroundColor: AppTheme.accentOrange,
            child: const Icon(
              Icons.shopping_cart_rounded,
              size: 22,
            ),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CartScreen(),
              ),
            );
          },
          tooltip: 'Ver Carrito',
        ),
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
            isLabelVisible: isFilterActive,
            backgroundColor: AppTheme.accentOrange,
            smallSize: 8,
            child: Icon(
              _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              size: 22,
            ),
          ),
          onPressed: _toggleFilters,
        ),
        if (isFilterActive)
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, size: 22),
            onPressed: _clearFilters,
            tooltip: 'Limpiar filtros',
          ),
      ],
    );

    final mainContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isWeb
            ? _buildWebLayout(results, query)
            : Column(
                children: [
                  // === BARRA DE CONECTIVIDAD OFF-LINE ===
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _isOffline ? 36 : 0,
                    width: double.infinity,
                    color: AppTheme.errorRed.withOpacity(0.9),
                    alignment: Alignment.center,
                    child: _isOffline
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Modo Offline Activo - Cargando datos locales desde caché',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : const SizedBox(),
                  ),
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
                    child: ref.watch(catalogoStreamProvider).when(
                      data: (_) {
                        return results.isEmpty
                            ? _buildEmptyState(query)
                            : _buildProductGrid(results);
                      },
                      loading: () => _buildShimmerGrid(),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error al cargar catálogo: $err',
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'catalog'),
      floatingActionButton: widget.userRole == 'admin'
          ? FloatingActionButton(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
              onPressed: () => _openAddEditProductDialog(),
            )
          : null,
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _buildWebLayout(List<CatalogoProducto> results, String query) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sidebar de Filtros (Fijo)
        Container(
          width: 280,
          margin: const EdgeInsets.only(left: 16, top: 16, bottom: 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FILTRAR POR',
                      style: GoogleFonts.outfit(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all_rounded, size: 18, color: AppTheme.textGray),
                      onPressed: _clearFilters,
                      tooltip: 'Limpiar Filtros',
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                Text(
                  'BÚSQUEDA',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar herramientas...',
                    hintStyle: const TextStyle(color: AppTheme.textGray),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.textGray),
                    fillColor: Colors.white.withOpacity(0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'CATEGORÍAS',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildWebCategoryList(),
                const SizedBox(height: 20),
                Text(
                  'RANGO DE PRECIO',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildWebPriceSlider(),
              ],
            ),
          ),
        ),

        // 2. Grilla de Productos
        Expanded(
          child: Column(
            children: [
              if (_isOffline)
                Container(
                  height: 36,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Modo Offline - Datos locales',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: ref.watch(catalogoStreamProvider).when(
                  data: (_) {
                    if (results.isEmpty) {
                      return _buildEmptyState(query);
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final prod = results[index];
                        return _buildGridCard(prod, index);
                      },
                    );
                  },
                  loading: () => _buildShimmerGrid(),
                  error: (err, stack) => Center(
                    child: Text('Error: $err', style: const TextStyle(color: AppTheme.errorRed)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebCategoryList() {
    final categories = ['Herramientas Manuales', 'Herramientas Eléctricas', 'Materiales de Construcción', 'Abrasivos y Consumibles', 'Equipos de Protección', 'Instrumentos de Medición'];
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Column(
      children: categories.map((cat) {
        final isSelected = selectedCategory == cat;
        return ListTile(
          onTap: () {
            ref.read(selectedCategoryProvider.notifier).state = isSelected ? null : cat;
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            _categoryIcons[cat] ?? Icons.category_rounded,
            size: 16,
            color: isSelected ? AppTheme.accentOrange : AppTheme.textGray,
          ),
          title: Text(
            cat,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textGray,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: AppTheme.accentOrange, size: 14)
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildWebPriceSlider() {
    final precioMin = ref.watch(precioMinProvider);
    final precioMax = ref.watch(precioMaxProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min: S/ ${precioMin.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textGray, fontSize: 10)),
            Text('Max: S/ ${precioMax > 5000 ? "Max" : precioMax.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textGray, fontSize: 10)),
          ],
        ),
        RangeSlider(
          values: RangeValues(precioMin, precioMax > 5000 ? 5000 : precioMax),
          min: 0,
          max: 5000,
          activeColor: AppTheme.accentOrange,
          inactiveColor: Colors.white10,
          onChanged: (values) {
            ref.read(precioMinProvider.notifier).state = values.start;
            ref.read(precioMaxProvider.notifier).state = values.end >= 5000 ? 999999.0 : values.end;
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isListening ? AppTheme.accentOrange : Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: _isListening ? AppTheme.accentOrange.withOpacity(0.15) : Colors.black.withOpacity(0.2),
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
          hintText: _isListening ? '🎤 Escuchando... habla ahora' : '🔍 Buscar por nombre, marca, categoría...',
          hintStyle: TextStyle(
            color: _isListening ? AppTheme.accentOrange : Colors.white.withOpacity(0.3),
            fontSize: 13,
            fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search_rounded, color: AppTheme.accentOrange, size: 22),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening ? AppTheme.accentOrange : AppTheme.textGray,
                ),
                tooltip: 'Búsqueda por Voz',
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textGray),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
            ],
          ),
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
    final marcas = ref.watch(marcasProvider);
    final selectedBrand = ref.watch(selectedBrandProvider);
    final precioMin = ref.watch(precioMinProvider);
    final precioMax = ref.watch(precioMaxProvider);

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
              Row(
                children: [
                  const Text('Solo stock disponible', style: TextStyle(color: AppTheme.textGray, fontSize: 10)),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 30,
                    child: Switch(
                      value: soloDisponibles,
                      onChanged: (v) => ref.read(soloDisponiblesProvider.notifier).state = v,
                      activeColor: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          Row(
            children: [
              const Icon(Icons.business_rounded, color: AppTheme.textGray, size: 14),
              const SizedBox(width: 8),
              const Text('Marca:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBrand,
                      hint: const Text('Todas las marcas', style: TextStyle(color: AppTheme.textGray, fontSize: 11)),
                      dropdownColor: AppTheme.surfaceDark,
                      iconEnabledColor: AppTheme.accentOrange,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todas las marcas'),
                        ),
                        ...marcas.map((brand) => DropdownMenuItem<String>(
                          value: brand,
                          child: Text(brand),
                        )),
                      ],
                      onChanged: (val) => ref.read(selectedBrandProvider.notifier).state = val,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.monetization_on_rounded, color: AppTheme.textGray, size: 14),
                      SizedBox(width: 8),
                      Text('Rango de precio:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    'S/ ${precioMin.toStringAsFixed(0)} - ${precioMax > 1000 ? 'Máx' : 'S/ ${precioMax.toStringAsFixed(0)}'}',
                    style: const TextStyle(color: AppTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RangeSlider(
                values: RangeValues(precioMin, precioMax > 500.0 ? 500.0 : precioMax),
                min: 0.0,
                max: 500.0,
                divisions: 50,
                activeColor: AppTheme.accentOrange,
                inactiveColor: Colors.white12,
                onChanged: (RangeValues values) {
                  ref.read(precioMinProvider.notifier).state = values.start;
                  ref.read(precioMaxProvider.notifier).state = values.end == 500.0 ? 999999.0 : values.end;
                },
              ),
            ],
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
      final screenWidth = MediaQuery.of(context).size.width;
      int crossAxisCount = 2;
      double childAspectRatio = 0.54;

      if (screenWidth >= 1400) {
        crossAxisCount = 6;
        childAspectRatio = 0.72;
      } else if (screenWidth >= 1100) {
        crossAxisCount = 5;
        childAspectRatio = 0.68;
      } else if (screenWidth >= 850) {
        crossAxisCount = 4;
        childAspectRatio = 0.64;
      } else if (screenWidth >= 600) {
        crossAxisCount = 3;
        childAspectRatio = 0.60;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 0.54;
      }

      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
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
        return 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop';
      case 'Herramientas Eléctricas':
        return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop';
      case 'Materiales de Construcción':
        return 'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=500&auto=format&fit=crop';
      case 'Seguridad Industrial':
        return 'https://images.unsplash.com/photo-1508962914676-134849a727f0?w=500&auto=format&fit=crop';
      case 'Fijaciones y Tornillería':
        return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop';
      case 'Abrasivos y Consumibles':
        return 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=500&auto=format&fit=crop';
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
                      Hero(
                        tag: 'hero-img-${producto.id}',
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: _buildProductImageWidget(
                            imageUrl,
                            producto.categoria,
                            width: double.infinity,
                            height: double.infinity,
                            placeholderIconSize: 32,
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton(
                          onPressed: !producto.disponible
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).addItem(producto);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${producto.nombre} agregado al carrito.'),
                                      backgroundColor: AppTheme.successGreen,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentOrange,
                            disabledBackgroundColor: Colors.white.withOpacity(0.05),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart_rounded, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'AL CARRITO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
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
            height: 130,
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
                        Hero(
                          tag: 'hero-img-${producto.id}',
                          child: _buildProductImageWidget(
                            imageUrl,
                            producto.categoria,
                            width: 110,
                            height: double.infinity,
                            placeholderIconSize: 28,
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
                  // Detalles en el medio
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'S/ ${producto.precioUnitario.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
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
                  // Botón de Compra Vertical (Extremo derecho)
                  Material(
                    color: producto.disponible ? AppTheme.accentOrange : Colors.white.withOpacity(0.05),
                    child: InkWell(
                      onTap: !producto.disponible
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              ref.read(cartProvider.notifier).addItem(producto);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${producto.nombre} agregado al carrito.'),
                                  backgroundColor: AppTheme.successGreen,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                      child: Container(
                        width: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white.withOpacity(0.04)),
                          ),
                        ),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                producto.disponible
                                    ? Icons.add_shopping_cart_rounded
                                    : Icons.remove_shopping_cart_rounded,
                                size: 14,
                                color: producto.disponible ? Colors.white : AppTheme.textGray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                producto.disponible ? 'AL CARRITO' : 'AGOTADO',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: producto.disponible ? Colors.white : AppTheme.textGray,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
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

    final catalogoAsync = ref.read(catalogoStreamProvider);
    List<CatalogoProducto> similarProducts = [];
    if (catalogoAsync.hasValue) {
      similarProducts = catalogoAsync.value!
          .where((p) => p.categoria == producto.categoria && p.id != producto.id)
          .toList();
    }

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
                      Hero(
                        tag: 'hero-img-${producto.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildProductImageWidget(
                            imageUrl,
                            producto.categoria,
                            width: 64,
                            height: 64,
                            placeholderIconSize: 32,
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
                  const SizedBox(height: 20),
                  if (producto.disponible) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).addItem(producto);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${producto.nombre}" agregado al carrito.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('AGREGAR AL CARRITO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                  
                  // --- SECCIÓN DE VALORACIONES Y OPINIONES ---
                  const SizedBox(height: 24),
                  const Text(
                    'OPINIONES Y VALORACIONES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('catalogo_productos')
                        .doc(producto.id)
                        .collection('resenas')
                        .orderBy('fecha', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange, strokeWidth: 2));
                      }
                      
                      final docs = snapshot.data?.docs ?? [];
                      
                      // Calcular promedio de estrellas
                      double avgStars = 0.0;
                      if (docs.isNotEmpty) {
                        final totalStars = docs.fold<double>(0.0, (sum, doc) {
                          final val = double.tryParse(doc.data()['estrellas']?.toString() ?? '0.0') ?? 0.0;
                          return sum + val;
                        });
                        avgStars = totalStars / docs.length;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  final starVal = index + 1;
                                  if (starVal <= avgStars.round()) {
                                    return const Icon(Icons.star_rounded, color: Colors.amber, size: 20);
                                  } else {
                                    return const Icon(Icons.star_outline_rounded, color: Colors.white24, size: 20);
                                  }
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                docs.isNotEmpty
                                    ? '${avgStars.toStringAsFixed(1)} / 5.0 (${docs.length} ${docs.length == 1 ? 'reseña' : 'reseñas'})'
                                    : 'Sin valoraciones aún',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (docs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Sé el primero en calificar este producto.', style: TextStyle(color: AppTheme.textGray, fontSize: 11)),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final data = docs[idx].data();
                                final String user = data['usuario_nombre'] ?? 'Comprador Aly';
                                final double stars = double.tryParse(data['estrellas']?.toString() ?? '0.0') ?? 0.0;
                                final String comment = data['comentario'] ?? '';
                                final String dateRaw = data['fecha'] ?? '';
                                final String? imgBase64 = data['imagen_base64'];

                                String dateStr = 'N/A';
                                if (dateRaw.isNotEmpty) {
                                  try {
                                    final parsed = DateTime.parse(dateRaw);
                                    dateStr = DateFormat('dd/MM/yyyy').format(parsed);
                                  } catch (_) {}
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(user, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                          Text(dateStr, style: const TextStyle(color: AppTheme.textGray, fontSize: 9)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < stars.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                            color: index < stars.round() ? Colors.amber : Colors.white10,
                                            size: 12,
                                          );
                                        }),
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(comment, style: const TextStyle(color: AppTheme.textGray, fontSize: 11, height: 1.4)),
                                      ],
                                      if (imgBase64 != null && imgBase64.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                backgroundColor: Colors.transparent,
                                                child: InteractiveViewer(
                                                  child: Image.memory(base64Decode(imgBase64)),
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.memory(
                                              base64Decode(imgBase64),
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _mostrarDialogoResena(producto),
                              icon: const Icon(Icons.rate_review_outlined, size: 16),
                              label: const Text('ESCRIBIR UNA RESEÑA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentOrange,
                                side: const BorderSide(color: AppTheme.accentOrange),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // --- SECCIÓN DE PRODUCTOS SIMILARES ---
                  if (similarProducts.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'PRODUCTOS SIMILARES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: similarProducts.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final p = similarProducts[index];
                          final pImg = _getProductImage(p);
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Future.delayed(const Duration(milliseconds: 300), () {
                                _showProductDetail(p);
                              });
                            },
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildProductImageWidget(
                                      pImg,
                                      p.categoria,
                                      width: double.infinity,
                                      height: 60,
                                      placeholderIconSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Text(
                                      p.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    'S/ ${p.precioUnitario.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppTheme.successGreen, fontSize: 8.5, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

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

  void _mostrarDialogoResena(CatalogoProducto producto) {
    double selectedRating = 5;
    final commentController = TextEditingController();
    XFile? pickedImage;
    String? base64Image;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> _pickImage(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: source,
                imageQuality: 25,
                maxWidth: 400,
                maxHeight: 400,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                setState(() {
                  pickedImage = file;
                  base64Image = base64Encode(bytes);
                });
              }
            } catch (e) {
              debugPrint('Error seleccionando imagen: $e');
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'VALORAR PRODUCTO',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('CALIFICACIÓN:', style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: starValue <= selectedRating ? Colors.amber : Colors.white24,
                          size: 32,
                        ),
                        onPressed: () => setState(() => selectedRating = starValue.toDouble()),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('TU OPINIÓN (COMENTARIO):', style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos tu experiencia con este producto...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      fillColor: Colors.white.withOpacity(0.02),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('FOTO DEL PRODUCTO (OPCIONAL):', style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (base64Image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(base64Image!), height: 100, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isSubmitting ? null : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 14),
                        label: const Text('CÁMARA', style: TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.04),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(100, 36),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isSubmitting ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 14),
                        label: const Text('GALERÍA', style: TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.04),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(100, 36),
                        ),
                      ),
                    ],
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(color: AppTheme.accentOrange, backgroundColor: Colors.white10),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final firestore = FirebaseFirestore.instance;

                          if (currentUser == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Debes iniciar sesión para valorar un producto.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setState(() => isSubmitting = false);
                            return;
                          }

                          String userName = 'Cliente Aly';
                          try {
                            final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
                            if (userDoc.exists) {
                              userName = userDoc.data()?['nombre'] ?? userDoc.data()?['email'] ?? 'Comprador Aly';
                            } else {
                              userName = currentUser.displayName ?? currentUser.email ?? 'Comprador Aly';
                            }
                          } catch (_) {
                            userName = currentUser.displayName ?? currentUser.email ?? 'Comprador Aly';
                          }

                          await firestore
                              .collection('catalogo_productos')
                              .doc(producto.id)
                              .collection('resenas')
                              .add({
                            'usuario_nombre': userName,
                            'estrellas': selectedRating,
                            'comentario': commentController.text.trim(),
                            'fecha': DateTime.now().toIso8601String(),
                            'imagen_base64': base64Image,
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Muchas gracias por valorar este producto! Reseña publicada.'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error al enviar reseña: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al publicar la reseña: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                          setState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ENVIAR'),
              ),
            ],
          );
        },
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

  Widget _buildShimmerGrid() {
    if (_isGridView) {
      final screenWidth = MediaQuery.of(context).size.width;
      int crossAxisCount = 2;
      double childAspectRatio = 0.54;

      if (screenWidth >= 1400) {
        crossAxisCount = 6;
        childAspectRatio = 0.72;
      } else if (screenWidth >= 1100) {
        crossAxisCount = 5;
        childAspectRatio = 0.68;
      } else if (screenWidth >= 850) {
        crossAxisCount = 4;
        childAspectRatio = 0.64;
      } else if (screenWidth >= 600) {
        crossAxisCount = 3;
        childAspectRatio = 0.60;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 0.54;
      }

      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildShimmerCard(),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => _buildShimmerListCard(),
      );
    }
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.03),
        highlightColor: Colors.white.withOpacity(0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 8, width: 60, color: Colors.white10),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.white10),
                  const SizedBox(height: 6),
                  Container(height: 8, width: 40, color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(height: 14, width: 50, color: Colors.white10),
                      Container(height: 24, width: 24, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerListCard() {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.03),
        highlightColor: Colors.white.withOpacity(0.08),
        child: Row(
          children: [
            Container(
              width: 110,
              decoration: const BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 8, width: 80, color: Colors.white10),
                        const SizedBox(height: 8),
                        Container(height: 14, width: 140, color: Colors.white10),
                        const SizedBox(height: 6),
                        Container(height: 8, width: 60, color: Colors.white10),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(height: 16, width: 60, color: Colors.white10),
                        Container(height: 28, width: 28, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  bool _isUploadingToDrive = false;
  bool _showAdvancedDriveSettings = false;
  late TextEditingController _customAppsScriptUrlCtrl;

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
    _imagenUrlCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    _customAppsScriptUrlCtrl = TextEditingController(text: GoogleDriveService.appsScriptUrl);
    
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
    _customAppsScriptUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    ImageSource? selectedSource;

    if (!mounted) return;
    
    // Diálogo interactivo para que el usuario seleccione la fuente
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Origen de la Imagen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Selecciona si deseas tomar una foto en vivo con la cámara o cargarla desde la galería de tu dispositivo.', style: TextStyle(color: AppTheme.textGray, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton.icon(
            onPressed: () {
              selectedSource = ImageSource.camera;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentOrange, size: 18),
            label: const Text('Cámara', style: TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () {
              selectedSource = ImageSource.gallery;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.photo_library_rounded, color: AppTheme.accentOrange, size: 18),
            label: const Text('Galería', style: TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (selectedSource == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: selectedSource!,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploadingToDrive = true;
      });

      final bytes = await image.readAsBytes();
      final filename = image.name;

      // Persistir la URL ingresada para que se guarde en el dispositivo
      await GoogleDriveService.persistUrl(_customAppsScriptUrlCtrl.text);

      final driveService = GoogleDriveService();
      final resultUrl = await driveService.uploadImage(
        bytes,
        filename,
        customUrl: _customAppsScriptUrlCtrl.text,
      );

      if (resultUrl != null) {
        setState(() {
          _imagenUrlCtrl.text = resultUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Imagen subida correctamente a Google Drive!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permiso denegado o error: Por favor habilita los permisos de cámara y almacenamiento en los ajustes del dispositivo.'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingToDrive = false;
        });
      }
    }
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Imagen del Producto',
                            style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(_imagenUrlCtrl, 'URL de la Imagen', 'https://images.unsplash.com/...'),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isUploadingToDrive ? null : _pickAndUploadImage,
                                  icon: _isUploadingToDrive 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                        )
                                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                                  label: Text(_isUploadingToDrive ? 'SUBIENDO...' : 'DRIVE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.surfaceDark,
                                    foregroundColor: AppTheme.accentOrange,
                                    side: BorderSide(color: AppTheme.accentOrange.withOpacity(0.5)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_imagenUrlCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildProductImageWidget(
                                _imagenUrlCtrl.text,
                                _categoria,
                                height: 80,
                                width: double.infinity,
                                placeholderIconSize: 24,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showAdvancedDriveSettings = !_showAdvancedDriveSettings;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showAdvancedDriveSettings ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppTheme.accentOrange,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Configuración Avanzada de Google Drive',
                                  style: TextStyle(color: AppTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (_showAdvancedDriveSettings) ...[
                            const SizedBox(height: 8),
                            _buildTextField(
                              _customAppsScriptUrlCtrl,
                              'URL de Google Apps Script Web App',
                              'https://script.google.com/macros/s/.../exec',
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pega la URL desplegada de tu Google Apps Script. Las fotos seleccionadas se guardarán en tu Drive.',
                              style: TextStyle(color: AppTheme.textGray, fontSize: 8),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildProductImageWidget(String imageUrl, String categoria, {double? width, double? height, BoxFit fit = BoxFit.cover, double placeholderIconSize = 28}) {
    final color = _CatalogoScreenState._categoryColors[categoria] ?? AppTheme.accentOrange;
    
    if (imageUrl.trim().isEmpty) {
      return Container(
        color: color.withOpacity(0.1),
        child: Center(
          child: Icon(
            _CatalogoScreenState._categoryIcons[categoria] ?? Icons.category_rounded,
            color: color,
            size: placeholderIconSize,
          ),
        ),
      );
    }
    
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: color.withOpacity(0.1),
            child: Center(
              child: Icon(
                _CatalogoScreenState._categoryIcons[categoria] ?? Icons.category_rounded,
                color: color,
                size: placeholderIconSize,
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decodificando base64: $e');
      }
    }
    
    final int? cWidth = (width != null && width.isFinite && width > 0) ? (width * 2.0).toInt() : 300;
    final int? cHeight = (height != null && height.isFinite && height > 0) ? (height * 2.0).toInt() : 300;

    return Image.network(
      imageUrl,
      headers: (imageUrl.contains('google') || imageUrl.contains('drive')) ? _CatalogoScreenState._imageHeaders : null,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cWidth,
      cacheHeight: cHeight,
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
            _CatalogoScreenState._categoryIcons[categoria] ?? Icons.category_rounded,
            color: color,
            size: placeholderIconSize,
          ),
        ),
      ),
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
