import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';

class ArMeasurementScreen extends StatefulWidget {
  const ArMeasurementScreen({super.key});

  @override
  State<ArMeasurementScreen> createState() => _ArMeasurementScreenState();
}

class _ArMeasurementScreenState extends State<ArMeasurementScreen> {
  StreamSubscription? _accelerometerSubscription;
  File? _backgroundImage;
  Uint8List? _webImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Ángulos calculados
  double _pitch = 0.0; 
  double _roll = 0.0;  
  bool _isAligned = false;
  bool _hasHapticFeedbackFired = false;
  bool _useSimulation = kIsWeb;

  // Estado del producto proyectado
  String _selectedProduct = 'Nivelador Láser Aly Pro';
  double _productX = 0.0; // Offset X (-150 a 150)
  double _productY = 0.0; // Offset Y (-150 a 150)
  double _productRotation = 0.0; // En radianes
  double _productScale = 1.0; // Escala (0.5 a 2.0)

  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Nivelador Láser Aly Pro',
      'icon': '🚨',
      'description': 'Láser autonivelante de 360 grados para obras industriales.',
      'size': '25 x 12 cm',
    },
    {
      'name': 'Rotomartillo Aly Torque-X',
      'icon': '🔨',
      'description': 'Rotomartillo de alta potencia para perforaciones en concreto.',
      'size': '45 x 20 cm',
    },
    {
      'name': 'Nivelador Digital Industrial Aly',
      'icon': '📐',
      'description': 'Nivel digital con sensor magnético de alta precisión.',
      'size': '15 x 5 cm',
    },
    {
      'name': 'Sierra Circular Pro-Aly',
      'icon': '🪚',
      'description': 'Sierra circular de alto torque con guías de corte láser.',
      'size': '35 x 25 cm',
    }
  ];

  @override
  void initState() {
    super.initState();
    if (!_useSimulation) {
      _startAccelerometerListening();
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _startAccelerometerListening() {
    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          double x = event.x;
          double y = event.y;
          double z = event.z;

          // Calcular inclinación en grados
          double pitchVal = atan2(y, z) * 180 / pi;
          double rollVal = atan2(-x, sqrt(y * y + z * z)) * 180 / pi;

          if (mounted) {
            setState(() {
              _pitch = pitchVal;
              _roll = rollVal;
              // Tolerancia de alineación de 1.0 grados
              _isAligned = _pitch.abs() < 1.0 && _roll.abs() < 1.0;

              if (_isAligned) {
                if (!_hasHapticFeedbackFired) {
                  HapticFeedback.heavyImpact();
                  _hasHapticFeedbackFired = true;
                }
              } else {
                _hasHapticFeedbackFired = false;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Error en acelerómetro físico AR: $error');
          setState(() {
            _useSimulation = true;
          });
        },
      );
    } catch (e) {
      setState(() {
        _useSimulation = true;
      });
    }
  }

  Future<void> _pickCameraBackground() async {
    ImageSource? source;
    
    // Permitir elegir cámara o galería
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Fondo de Obra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tome una foto en vivo de la pared/obra con la cámara o cargue una de su galería para superponer la herramienta.',
          style: TextStyle(color: AppTheme.textGray, fontSize: 13),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              source = ImageSource.camera;
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentOrange),
            label: const Text('Cámara', style: TextStyle(color: AppTheme.accentOrange)),
          ),
          TextButton.icon(
            onPressed: () {
              source = ImageSource.gallery;
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.photo_library_rounded, color: AppTheme.accentOrange),
            label: const Text('Galería', style: TextStyle(color: AppTheme.accentOrange)),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source!,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file != null) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
            _backgroundImage = null;
          });
        } else {
          setState(() {
            _backgroundImage = File(file.path);
            _webImageBytes = null;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de obra cargada como fondo AR.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando imagen de cámara: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    }
  }

  void _resetProjectedItem() {
    setState(() {
      _productX = 0.0;
      _productY = 0.0;
      _productRotation = 0.0;
      _productScale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final laserColor = _isAligned ? AppTheme.successGreen : AppTheme.errorRed;
    final currentProdData = _products.firstWhere((p) => p['name'] == _selectedProduct);
    final bool isWeb = kIsWeb || MediaQuery.of(context).size.width >= 900;

    final appBar = AppBar(
      title: Text(
        'MEDIDOR LÁSER AR & PROYECCIÓN',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
      ),
      leading: isWeb
          ? null
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.flip_camera_ios_rounded, color: AppTheme.accentOrange),
          onPressed: _pickCameraBackground,
          tooltip: 'Capturar Fondo de Obra',
        ),
      ],
    );

    final mainContent = Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo de la cámara (Imagen real cargada o Simulación High-Tech Blueprint)
        kIsWeb
            ? (_webImageBytes != null
                ? Image.memory(
                    _webImageBytes!,
                    fit: BoxFit.cover,
                  )
                : _buildSimulatedCameraBackground())
            : (_backgroundImage != null
                ? Image.file(
                    _backgroundImage!,
                    fit: BoxFit.cover,
                  )
                : _buildSimulatedCameraBackground()),

        // 2. Líneas láser virtuales (Horizontal y Vertical)
        _buildVirtualLaserLines(laserColor),

        // 3. Herramienta industrial proyectada y arrastrable (AR Layer)
        _buildProjectedToolLayer(currentProdData),

        // 4. Panel superior de Lectura de Ángulos y Estado
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildAngleOverlayPanel(laserColor),
        ),

        // 5. Panel inferior de Controles de Proyección y selección de producto
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildControlPanel(currentProdData),
        ),
      ],
    );

    if (isWeb) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Row(
          children: [
            const WebSidebar(currentRoute: 'ar_camera'),
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: appBar,
                body: mainContent,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        drawer: const AppDrawer(currentRoute: 'ar_camera'),
        appBar: appBar,
        body: mainContent,
      );
    }
  }

  Widget _buildSimulatedCameraBackground() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070B19),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF0F1A35),
            AppTheme.primaryDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Cuadrícula técnica (Blueprint)
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(),
          ),
          
          // Efecto de escáner animado
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined, size: 48, color: Colors.white24),
                SizedBox(height: 12),
                Text(
                  'SIMULADOR DE CÁMARA ACTIVO',
                  style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                SizedBox(height: 4),
                Text(
                  'Presione el ícono de cámara superior para tomar una foto real.',
                  style: TextStyle(color: Colors.white12, fontSize: 9),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVirtualLaserLines(Color laserColor) {
    return Stack(
      children: [
        // Línea Horizontal
        Center(
          child: Container(
            width: double.infinity,
            height: 2,
            decoration: BoxDecoration(
              color: laserColor,
              boxShadow: [
                BoxShadow(
                  color: laserColor.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // Línea Vertical
        Center(
          child: Container(
            width: 2,
            height: double.infinity,
            decoration: BoxDecoration(
              color: laserColor,
              boxShadow: [
                BoxShadow(
                  color: laserColor.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectedToolLayer(Map<String, dynamic> prod) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(_productX, _productY),
          child: Transform.rotate(
            angle: _productRotation,
            child: Transform.scale(
              scale: _productScale,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _productX += details.delta.dx;
                    _productY += details.delta.dy;
                  });
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentOrange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentOrange.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        prod['icon'] as String,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          (prod['name'] as String).toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prod['size'] as String,
                        style: const TextStyle(color: AppTheme.textGray, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAngleOverlayPanel(Color laserColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: laserColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAligned ? 'ALINEADO NIVELADO' : 'AJUSTANDO ALINEACIÓN',
                    style: GoogleFonts.outfit(
                      color: laserColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('GUÍA LÁSER DE PREVISUALIZACIÓN', style: TextStyle(color: AppTheme.textGray, fontSize: 8)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _angleBox('PITCH', '${_pitch.toStringAsFixed(1)}°'),
              const SizedBox(width: 8),
              _angleBox('ROLL', '${_roll.toStringAsFixed(1)}°'),
            ],
          )
        ],
      ),
    );
  }

  Widget _angleBox(String axis, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(axis, style: const TextStyle(color: AppTheme.textGray, fontSize: 7, fontWeight: FontWeight.bold)),
          Text(val, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControlPanel(Map<String, dynamic> prod) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Selector de Producto
          Row(
            children: [
              const Icon(Icons.playlist_add_check_rounded, color: AppTheme.accentOrange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProduct,
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      iconEnabledColor: AppTheme.accentOrange,
                      items: _products.map((p) => DropdownMenuItem<String>(
                        value: p['name'] as String,
                        child: Text(p['name'] as String),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedProduct = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 2. Descripción breve del producto
          Text(
            prod['description'] as String,
            style: const TextStyle(color: AppTheme.textGray, fontSize: 9, height: 1.3),
          ),
          const Divider(color: Colors.white10, height: 16),

          // 3. Sliders de Rotación y Escala
          Row(
            children: [
              const Icon(Icons.rotate_right_rounded, color: AppTheme.textGray, size: 14),
              const SizedBox(width: 8),
              const Text('ROTAR', style: TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _productRotation,
                    min: 0.0,
                    max: 2 * pi,
                    activeColor: AppTheme.accentOrange,
                    inactiveColor: Colors.white10,
                    onChanged: (val) => setState(() => _productRotation = val),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.zoom_in_rounded, color: AppTheme.textGray, size: 14),
              const SizedBox(width: 8),
              const Text('ESCALA', style: TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _productScale,
                    min: 0.5,
                    max: 2.0,
                    activeColor: AppTheme.accentOrange,
                    inactiveColor: Colors.white10,
                    onChanged: (val) => setState(() => _productScale = val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Botón Restablecer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _resetProjectedItem,
                icon: const Icon(Icons.restore_rounded, size: 14, color: AppTheme.textGray),
                label: const Text('REAJUSTAR OBJETO', style: TextStyle(color: AppTheme.textGray, fontSize: 9)),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Proyección de ${_selectedProduct} guardada en el reporte!'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  minimumSize: const Size(120, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('CAPTURAR OBRA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1.0;

    const double step = 20.0;
    
    // Dibujar líneas verticales
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Dibujar líneas horizontales
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
