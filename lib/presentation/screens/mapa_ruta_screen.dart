import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/geolocalizacion_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/ruta_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';

class MapaRutaScreen extends StatefulWidget {
  final String? usuarioId;
  const MapaRutaScreen({super.key, this.usuarioId});

  @override
  State<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends State<MapaRutaScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isDrawingRoute = false;
  bool _geofenceAlertTriggered = false;

  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  RutaModel? _rutaActual;

  final GeolocalizacionService _geolocatorService = GeolocalizacionService();

  // Coordenadas oficiales de la Tienda de Comercializadora Aly
  final LatLng _tiendaLatLng = const LatLng(
    GeolocalizacionService.tiendaLat,
    GeolocalizacionService.tiendaLng,
  );

  // Token oficial de Mapbox provisto por el usuario
  static const String _mapboxToken = 'pk.eyJ1Ijoiam9zZWJhYyIsImEiOiJjbW9pYTU0MW8wMGM4MnNvZ3NhOHo1NWM4In0.5Gw3E-h62DwI4ks5Y70cDw';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si los servicios de ubicación están activos
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los servicios de ubicación están desactivados.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los permisos de ubicación están denegados permanentemente.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Obtener la posición actual con límite de tiempo (timeout)
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _initMapElements();
    } catch (e) {
      debugPrint('Error obteniendo coordenadas GPS: $e');
      // Poner ubicación por defecto en Huancayo si falla o expira el tiempo
      _currentPosition = Position(
        latitude: -12.0668,
        longitude: -75.2157,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      setState(() {
        _isLoading = false;
      });
      _initMapElements();
    }
  }

  void _initMapElements() {
    if (_currentPosition == null) return;

    final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    setState(() {
      _markers.clear();
      
      // Marcador de la Tienda (Naranja Aly)
      _markers.add(
        Marker(
          point: _tiendaLatLng,
          width: 90,
          height: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentOrange, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Text(
                  'Tienda Aly',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              const Icon(
                Icons.location_on_rounded,
                color: AppTheme.accentOrange,
                size: 32,
              ),
            ],
          ),
        ),
      );

      // Marcador del Usuario (Cian)
      _markers.add(
        Marker(
          point: userLatLng,
          width: 90,
          height: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  border: Border.fromBorderSide(BorderSide(color: Colors.cyan, width: 1.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  'Tu Ubicación',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 2),
              Icon(
                Icons.my_location_rounded,
                color: Colors.cyan,
                size: 28,
              ),
            ],
          ),
        ),
      );
    });

    _fetchAndDrawRoute();
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_currentPosition == null) return;
    setState(() => _isDrawingRoute = true);

    try {
      final ruta = await _geolocatorService.obtenerRuta(
        origenLat: _currentPosition!.latitude,
        origenLng: _currentPosition!.longitude,
        destinoLat: _tiendaLatLng.latitude,
        destinoLng: _tiendaLatLng.longitude,
        usuarioId: widget.usuarioId,
        tipo: 'usuario_a_tienda',
      );

      if (ruta != null && ruta.polyline.isNotEmpty) {
        final decodedPoints = _decodePolyline(ruta.polyline);
        setState(() {
          _rutaActual = ruta;
          _polylines.add(
            Polyline(
              points: decodedPoints,
              color: AppTheme.accentOrange,
              strokeWidth: 5,
            ),
          );
        });
      } else {
        // Fallback simulación de ruta directa si el API key falla
        _simulateRoute();
      }
    } catch (e) {
      debugPrint('Error en la llamada a Directions API: $e');
      _simulateRoute();
    } finally {
      if (mounted) setState(() => _isDrawingRoute = false);
    }
  }

  void _simulateRoute() {
    if (_currentPosition == null) return;
    debugPrint('🗺️ Geolocalizacion: Simulando ruta directa (Fallback)');
    final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    // Calcular distancia aproximada
    final distanceInMeters = Geolocator.distanceBetween(
      userLatLng.latitude,
      userLatLng.longitude,
      _tiendaLatLng.latitude,
      _tiendaLatLng.longitude,
    );
    final distanceKm = (distanceInMeters / 1000).toStringAsFixed(1);
    
    setState(() {
      _rutaActual = RutaModel(
        id: 'simulado',
        origenLat: userLatLng.latitude,
        origenLng: userLatLng.longitude,
        destinoLat: _tiendaLatLng.latitude,
        destinoLng: _tiendaLatLng.longitude,
        distancia: '$distanceKm km',
        duracion: '${(distanceInMeters / 600).toStringAsFixed(0)} min',
        polyline: '',
        fechaConsulta: DateTime.now(),
        tipo: 'usuario_a_tienda',
      );

      // Dibujar línea recta punteada como fallback en flutter_map
      _polylines.add(
        Polyline(
          points: [userLatLng, _tiendaLatLng],
          color: AppTheme.accentOrange.withOpacity(0.8),
          strokeWidth: 4,
          pattern: StrokePattern.dashed(segments: const [15, 10]),
        ),
      );
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.startsWith('[')) {
      try {
        final List<dynamic> decoded = json.decode(encoded);
        return decoded.map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
      } catch (e) {
        debugPrint('Error decodificando GeoJSON coordinates: $e');
      }
    }

    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _zoomToFitAll() {
    if (_currentPosition == null) return;

    final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final bounds = LatLngBounds.fromPoints([userLatLng, _tiendaLatLng]);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  void _triggerGeofenceAlert() {
    if (_geofenceAlertTriggered) return;
    setState(() {
      _geofenceAlertTriggered = true;
    });

    // Disparar Notificación Local
    comunicateGeofenceNotification();

    // Mostrar Alerta en Pantalla
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: AppTheme.accentOrange),
            const SizedBox(width: 10),
            Text(
              'ARRIBO PRÓXIMO 📍',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'El GPS ha detectado que te encuentras a menos de 500 metros de la Tienda de Comercializadora Aly.\n\nHemos enviado una notificación al operador para que tus materiales y herramientas estén listas para retiro.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Future<void> comunicateGeofenceNotification() async {
    try {
      final NotificationService localNotifier = NotificationService();
      await localNotifier.showNotification(
        id: 999,
        title: '📍 Arribo Próximo a Tienda Aly',
        body: '¡Entraste al radio de 500m! Tu pedido de herramientas se está preparando.',
      );
    } catch (e) {
      debugPrint('Error triggering geofence notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(
        'RUTA A TIENDA ALY',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );

    final mainContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          )
        : Stack(
              children: [
                _currentPosition == null
                    ? const Center(
                        child: Text(
                          'No se pudo obtener la ubicación GPS.',
                          style: TextStyle(color: AppTheme.textGray),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          initialZoom: 14,
                          onMapReady: () {
                            _zoomToFitAll();
                          },
                        ),
                        children: [
                          // Capa de Mapa con estilo Oscuro de Mapbox y Token de usuario
                          TileLayer(
                            urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/512/{z}/{x}/{y}?access_token=$_mapboxToken',
                            tileSize: 512,
                            zoomOffset: -1,
                            userAgentPackageName: 'com.jose.stitch.stitch_app',
                          ),
                          PolylineLayer(
                            polylines: _polylines,
                          ),
                          MarkerLayer(
                            markers: _markers,
                          ),
                        ],
                      ),
                
                // Botón flotante para recentrar cámara
                if (_currentPosition != null) ...[
                  Positioned(
                    right: 16,
                    bottom: 200,
                    child: FloatingActionButton(
                      heroTag: 'geofence_sim',
                      mini: true,
                      backgroundColor: AppTheme.surfaceDark,
                      foregroundColor: Colors.cyan,
                      onPressed: () {
                        // Simular geocerca moviendo la posición actual a 200m de la tienda
                        setState(() {
                          _currentPosition = Position(
                            latitude: GeolocalizacionService.tiendaLat + 0.0018,
                            longitude: GeolocalizacionService.tiendaLng + 0.0018,
                            timestamp: DateTime.now(),
                            accuracy: 10.0,
                            altitude: 0.0,
                            altitudeAccuracy: 0.0,
                            heading: 0.0,
                            headingAccuracy: 0.0,
                            speed: 0.0,
                            speedAccuracy: 0.0,
                          );
                          _markers.clear();
                          // Volver a dibujar marcadores con la posición nueva
                          final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                          _markers.add(
                            Marker(
                              point: _tiendaLatLng,
                              width: 90,
                              height: 90,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceDark,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.accentOrange, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Text(
                                      'Tienda Aly',
                                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: AppTheme.accentOrange,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          );
                          _markers.add(
                            Marker(
                              point: userLatLng,
                              width: 90,
                              height: 90,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceDark,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.cyan, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Text(
                                      'Tu Ubicación (Simulada)',
                                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.cyan,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        });
                        
                        // Dibujar nueva ruta y disparar alerta
                        _fetchAndDrawRoute();
                        _triggerGeofenceAlert();
                      },
                      tooltip: 'Simular geocerca (500m)',
                      child: const Icon(Icons.satellite_alt_rounded),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 140,
                    child: FloatingActionButton(
                      heroTag: 'recenter_camera',
                      mini: true,
                      backgroundColor: AppTheme.surfaceDark,
                      foregroundColor: AppTheme.accentOrange,
                      onPressed: _zoomToFitAll,
                      child: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
                ],

                // Tarjeta de información de la ruta en la parte inferior
                if (_rutaActual != null)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.directions_car_rounded, color: AppTheme.accentOrange),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tienda Física Huancayo',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                    const Text(
                                      'Calle Real, Huancayo (Comercializadora Aly)',
                                      style: TextStyle(color: AppTheme.textGray, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoColumn('DISTANCIA', _rutaActual!.distancia, Icons.trending_up_rounded),
                              _infoColumn('DURACIÓN', _rutaActual!.duracion, Icons.access_time_filled_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'gps'),
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _infoColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.textGray, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
