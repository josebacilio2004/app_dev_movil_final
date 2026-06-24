import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/geolocalizacion_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/ruta_model.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';

class SeguimientoDeliveryScreen extends StatefulWidget {
  const SeguimientoDeliveryScreen({super.key});

  @override
  State<SeguimientoDeliveryScreen> createState() => _SeguimientoDeliveryScreenState();
}

class _SeguimientoDeliveryScreenState extends State<SeguimientoDeliveryScreen> {
  final MapController _mapController = MapController();
  final GeolocalizacionService _geoService = GeolocalizacionService();

  LatLng? _userLocation;
  final LatLng _tiendaLocation = const LatLng(
    GeolocalizacionService.tiendaLat,
    GeolocalizacionService.tiendaLng,
  );

  bool _isLoading = true;
  RutaModel? _ruta;
  List<LatLng> _routePoints = [];
  
  // Posición actual del camión
  LatLng? _truckPosition;
  int _currentRouteIndex = 0;
  Timer? _movementTimer;
  bool _deliveryFinished = false;

  // Estado del despacho
  String _statusMessage = 'Preparando Pedido en Almacén';
  double _completionPercent = 0.0;
  String _remainingDistance = '';
  String _remainingTime = '';

  static const String _mapboxToken = 'pk.eyJ1Ijoiam9zZWJhYyIsImEiOiJjbW9pYTU0MW8wMGM4MnNvZ3NhOHo1NWM4In0.5Gw3E-h62DwI4ks5Y70cDw';

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  Future<void> _initTracking() async {
    // 1. Intentar obtener coordenadas del comprador
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (serviceEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        _userLocation = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    // Fallback si no hay GPS/permisos (ej. en web o emulador sin geolocalización activa)
    // Trazaremos una dirección real en Huancayo
    _userLocation ??= const LatLng(-12.0668, -75.2157);

    // 2. Trazar ruta desde Tienda Aly hacia el comprador
    try {
      final route = await _geoService.obtenerRuta(
        origenLat: _tiendaLocation.latitude,
        origenLng: _tiendaLocation.longitude,
        destinoLat: _userLocation!.latitude,
        destinoLng: _userLocation!.longitude,
        tipo: 'tienda_a_usuario',
      );

      if (route != null && route.polyline.isNotEmpty) {
        _ruta = route;
        _routePoints = _decodePolyline(route.polyline);
      }
    } catch (e) {
      debugPrint('Error obteniendo ruta para delivery: $e');
    }

    // Fallback de simulación de ruta directa si Mapbox falla
    if (_routePoints.isEmpty) {
      _routePoints = _generateStraightLinePoints(_tiendaLocation, _userLocation!, 40);
      _ruta = RutaModel(
        id: 'sim_delivery',
        origenLat: _tiendaLocation.latitude,
        origenLng: _tiendaLocation.longitude,
        destinoLat: _userLocation!.latitude,
        destinoLng: _userLocation!.longitude,
        distancia: '${(Geolocator.distanceBetween(_tiendaLocation.latitude, _tiendaLocation.longitude, _userLocation!.latitude, _userLocation!.longitude) / 1000).toStringAsFixed(1)} km',
        duracion: '12 min',
        polyline: '',
        fechaConsulta: DateTime.now(),
        tipo: 'tienda_a_usuario',
      );
    }

    if (mounted) {
      setState(() {
        _truckPosition = _routePoints.first;
        _remainingDistance = _ruta!.distancia;
        _remainingTime = _ruta!.duracion;
        _isLoading = false;
      });

      // Recentrar cámara para ver ambos puntos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToFitAll();
        // Iniciar movimiento simulado del camión tras 2 segundos de preparación
        Future.delayed(const Duration(seconds: 2), _startTruckSimulation);
      });
    }
  }

  void _startTruckSimulation() {
    _movementTimer?.cancel();
    
    // Tasa de refresco: el camión avanza cada 350 milisegundos
    _movementTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (_currentRouteIndex >= _routePoints.length - 1) {
        timer.cancel();
        _handleDeliveryArrived();
        return;
      }

      setState(() {
        _currentRouteIndex++;
        _truckPosition = _routePoints[_currentRouteIndex];
        
        // Calcular porcentaje y datos restantes
        _completionPercent = _currentRouteIndex / (_routePoints.length - 1);
        
        // Simular variación en tiempo y distancia
        final double totalDist = double.tryParse(_ruta!.distancia.replaceAll(' km', '')) ?? 5.0;
        final double currentRemainingDist = totalDist * (1.0 - _completionPercent);
        _remainingDistance = '${currentRemainingDist.toStringAsFixed(1)} km';
        
        final double totalMin = double.tryParse(_ruta!.duracion.replaceAll(' min', '')) ?? 12.0;
        final int currentRemainingMin = (totalMin * (1.0 - _completionPercent)).round();
        _remainingTime = currentRemainingMin > 0 ? '$currentRemainingMin min' : 'Llegando';

        // Mensaje de estado dinámico
        if (_completionPercent < 0.15) {
          _statusMessage = 'Saliendo de Tienda Comercial Aly';
        } else if (_completionPercent < 0.50) {
          _statusMessage = 'En Tránsito: Av. Ferrocarril / Real';
        } else if (_completionPercent < 0.85) {
          _statusMessage = 'En Tránsito: Sector Urbano Próximo';
        } else {
          _statusMessage = 'Transporte Aly a menos de 100m';
        }
      });

      // Opcional: mover la cámara suavemente siguiendo al camión
      if (_currentRouteIndex % 5 == 0) {
        _mapController.move(_truckPosition!, _mapController.camera.zoom);
      }
    });
  }

  void _handleDeliveryArrived() {
    setState(() {
      _deliveryFinished = true;
      _statusMessage = '¡Pedido Entregado!';
      _remainingDistance = '0.0 km';
      _remainingTime = 'Llegó';
      _completionPercent = 1.0;
    });

    // Feedback táctil pesado
    HapticFeedback.vibrate();

    // Enviar notificación local
    try {
      NotificationService().showNotification(
        id: 111,
        title: '📦 ¡Tu pedido de Aly ha llegado!',
        body: 'El transporte de la empresa está en la dirección de entrega. Carlos te espera.',
      );
    } catch (_) {}

    // Mostrar modal premium
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.successGreen, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_rounded, color: AppTheme.successGreen, size: 28),
            const SizedBox(width: 12),
            Text(
              '¡TRANSPORTE ARRIBADO!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El vehículo de reparto de Comercializadora Aly ha llegado exitosamente al punto de entrega.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('👷‍♂️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carlos Mendoza (Conductor)',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Text(
                        'Placa: ALY-789 · Camión Fuso',
                        style: TextStyle(color: AppTheme.textGray, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );
  }

  void _zoomToFitAll() {
    if (_userLocation == null) return;
    final bounds = LatLngBounds.fromPoints([_tiendaLocation, _userLocation!]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 100, 60, 260),
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.startsWith('[')) {
      try {
        final List<dynamic> decoded = json.decode(encoded);
        return decoded.map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
      } catch (e) {
        debugPrint('Error decoding JSON coordinates: $e');
      }
    }
    return [];
  }

  List<LatLng> _generateStraightLinePoints(LatLng start, LatLng end, int steps) {
    List<LatLng> points = [];
    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double lat = start.latitude + (end.latitude - start.latitude) * t;
      double lng = start.longitude + (end.longitude - start.longitude) * t;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'delivery_tracking'),
      appBar: AppBar(
        title: Text(
          'SEGUIMIENTO DE TRANSPORTE',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            )
          : Stack(
              children: [
                // Mapa principal oscuro
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _truckPosition ?? _tiendaLocation,
                    initialZoom: 13.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/512/{z}/{x}/{y}?access_token=$_mapboxToken',
                      tileSize: 512,
                      zoomOffset: -1,
                      userAgentPackageName: 'com.jose.stitch.stitch_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        // Ruta completa en color opaco
                        Polyline(
                          points: _routePoints,
                          color: Colors.white12,
                          strokeWidth: 4,
                        ),
                        // Ruta recorrida por el camión
                        Polyline(
                          points: _routePoints.sublist(0, _currentRouteIndex + 1),
                          color: AppTheme.accentOrange,
                          strokeWidth: 5.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Marcador Origen: Tienda Aly
                        Marker(
                          point: _tiendaLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.business_rounded, color: Colors.white54, size: 28),
                        ),
                        // Marcador Destino: Ubicación Cliente
                        Marker(
                          point: _userLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on_rounded, color: Colors.cyan, size: 32),
                        ),
                        // Marcador Camión
                        if (_truckPosition != null)
                          Marker(
                            point: _truckPosition!,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accentOrange, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppTheme.accentOrange,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Controles flotantes rápidos
                Positioned(
                  right: 16,
                  bottom: 240,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'recenter_delivery',
                        mini: true,
                        backgroundColor: AppTheme.surfaceDark,
                        foregroundColor: Colors.white,
                        onPressed: _zoomToFitAll,
                        child: const Icon(Icons.center_focus_strong_rounded, size: 20),
                      ),
                    ],
                  ),
                ),

                // Panel de estado de logística premium en la parte inferior
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila superior: Estado y Porcentaje
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ESTADO DE LOGÍSTICA',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.accentOrange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _statusMessage,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _deliveryFinished 
                                    ? AppTheme.successGreen.withOpacity(0.1) 
                                    : AppTheme.accentOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(_completionPercent * 100).round()}%',
                                style: GoogleFonts.shareTechMono(
                                  color: _deliveryFinished ? AppTheme.successGreen : AppTheme.accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Barra de Progreso lineal
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _completionPercent,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _deliveryFinished ? AppTheme.successGreen : AppTheme.accentOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Métricas clave (Distancia, Tiempo)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _metricWidget('DISTANCIA RESTANTE', _remainingDistance, Icons.route_rounded),
                            _metricWidget('TIEMPO ESTIMADO', _remainingTime, Icons.hourglass_top_rounded),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 24),

                        // Ficha del Conductor
                        Row(
                          children: [
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Center(
                                child: Text('👷‍♂️', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Carlos Mendoza',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Camión Aly Fuso · ALY-789',
                                    style: TextStyle(
                                      color: AppTheme.textGray,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.successGreen.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.successGreen, size: 18),
                              ),
                              onPressed: () => _callDriverDialog(),
                              tooltip: 'Llamar al conductor',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricWidget(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textGray, size: 14),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _callDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text('Llamar Conductor', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Desea establecer una llamada telefónica directa con el transportador Carlos Mendoza al número +51 987 654 321?',
          style: TextStyle(color: AppTheme.textGray, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estableciendo conexión telefónica simulada...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('LLAMAR'),
          ),
        ],
      ),
    );
  }
}
