import 'dart:async';
import 'dart:convert';
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/cart_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/catalogo_producto.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArMeasurementScreen extends ConsumerStatefulWidget {
  const ArMeasurementScreen({super.key});

  @override
  ConsumerState<ArMeasurementScreen> createState() => _ArMeasurementScreenState();
}

class _ArMeasurementScreenState extends ConsumerState<ArMeasurementScreen> {
  StreamSubscription? _accelerometerSubscription;
  File? _backgroundImage;
  Uint8List? _webImageBytes;
  String? _base64BackgroundImage;
  bool _isEstimating = false;
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
      'image_url': 'https://i.imgur.com/8Qp4R8G.png',
      'description': 'Láser autonivelante de 360 grados para previsualizar alineaciones en obra.',
      'size': '25 x 12 cm',
    },
    {
      'name': 'Rotomartillo Aly Torque-X',
      'icon': '🔨',
      'image_url': 'https://i.imgur.com/BfA2l1M.png',
      'description': 'Rotomartillo de alta potencia para perforaciones en concreto.',
      'size': '45 x 20 cm',
    },
    {
      'name': 'Nivelador Digital Industrial Aly',
      'icon': '📐',
      'image_url': 'https://i.imgur.com/K5U0P1w.png',
      'description': 'Nivel digital con sensor magnético de alta precisión.',
      'size': '15 x 5 cm',
    },
    {
      'name': 'Sierra Circular Pro-Aly',
      'icon': '🪚',
      'image_url': 'https://i.imgur.com/J3t5C8g.png',
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
        final bytes = await file.readAsBytes();
        setState(() {
          _base64BackgroundImage = base64Encode(bytes);
          if (kIsWeb) {
            _webImageBytes = bytes;
            _backgroundImage = null;
          } else {
            _backgroundImage = File(file.path);
            _webImageBytes = null;
          }
        });
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
    final appBar = AppBar(
      title: Text(
        'MEDIDOR LÁSER AR & PROYECCIÓN',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.collections_bookmark_rounded, color: AppTheme.accentOrange),
          onPressed: _verBitacoraMediciones,
          tooltip: 'Ver Bitácora de Obra',
        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAngleOverlayPanel(laserColor),
              const SizedBox(height: 8),
              _buildInstructionsBanner(),
            ],
          ),
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

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'ar_camera'),
      appBar: appBar,
      body: mainContent,
    );
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
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentOrange.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentOrange.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      prod['image_url'] != null
                          ? Image.network(
                              prod['image_url'] as String,
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Text(
                                prod['icon'] as String,
                                style: const TextStyle(fontSize: 48),
                              ),
                            )
                          : Text(
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
                            shadows: [
                              const Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prod['size'] as String,
                        style: const TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 8,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 2),
                          ],
                        ),
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

          // 4. Botón Restablecer e IA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _resetProjectedItem,
                icon: const Icon(Icons.restore_rounded, size: 14, color: AppTheme.textGray),
                label: const Text('REAJUSTAR OBJETO', style: TextStyle(color: AppTheme.textGray, fontSize: 9)),
              ),
              Row(
                children: [
                  if (_isEstimating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppTheme.accentOrange, strokeWidth: 2),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _estimarMaterialesConIA,
                      icon: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                      label: const Text('ESTIMAR IA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _guardarCapturaObra,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('CAPTURAR OBRA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '💡 Indicaciones: Pulsa 📷 arriba a la derecha para tomar foto de tu pared. Arrastra y escala tu herramienta virtual, luego pulsa "CAPTURAR OBRA" para guardarla.',
              style: TextStyle(color: Colors.white, fontSize: 8.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  void _guardarCapturaObra() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inicia sesión para guardar tu medición en la bitácora.')),
        );
      }
      return;
    }

    if (_base64BackgroundImage == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: AppTheme.accentOrange),
              SizedBox(width: 10),
              Text('Fondo Requerido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          content: const Text(
            'Por favor, tome una foto de su pared con la cámara 📷 o cargue una de la galería antes de guardar la obra en tu bitácora.',
            style: TextStyle(color: AppTheme.textGray, fontSize: 12, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _pickCameraBackground();
              },
              child: const Text('CARGAR FOTO', style: TextStyle(color: AppTheme.accentOrange)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
            ),
          ],
        ),
      );
      return;
    }

    try {
      // 1. Guardar localmente en SharedPreferences (como registro de fallback)
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('saved_ar_projects') ?? [];
      final String record = 'Proyecto Medición - ${_selectedProduct} | Ángulo: ${_pitch.toStringAsFixed(1)}° | Escala: ${_productScale.toStringAsFixed(2)}x | Fecha: ${DateTime.now().toLocal().toString().substring(0, 16)}';
      list.add(record);
      await prefs.setStringList('saved_ar_projects', list);

      // 2. Guardar en Firestore de forma estructurada para el cliente actual
      await FirebaseFirestore.instance.collection('mediciones_ar').add({
        'usuario_id': currentUser.uid,
        'usuario_nombre': currentUser.displayName ?? currentUser.email ?? 'Cliente Aly',
        'producto_nombre': _selectedProduct,
        'pitch': _pitch,
        'roll': _roll,
        'escala': _productScale,
        'fecha': DateTime.now().toIso8601String(),
        'imagen_base64': _base64BackgroundImage,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
                SizedBox(width: 10),
                Text('Proyecto Guardado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            content: Text(
              '¡Medición de ${_selectedProduct} guardada con éxito en la Bitácora de Obra de tu cuenta!\n\nRegistro: "$record"',
              style: const TextStyle(color: AppTheme.textGray, fontSize: 12, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDIDO', style: TextStyle(color: AppTheme.accentOrange)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando proyecto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar medición en la nube: $e')),
        );
      }
    }
  }

  void _verBitacoraMediciones() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para ver tu bitácora de obra.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.collections_bookmark_rounded, color: AppTheme.accentOrange),
                    const SizedBox(width: 12),
                    Text(
                      'MI BITÁCORA DE OBRA AR',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('mediciones_ar')
                      .where('usuario_id', isEqualTo: currentUser.uid)
                      .orderBy('fecha', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📐', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 16),
                            Text(
                              'No tienes mediciones guardadas aún.',
                              style: TextStyle(color: AppTheme.textGray, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data();
                        final docId = docs[idx].id;
                        final String prodName = data['producto_nombre'] ?? 'Herramienta';
                        final double pitch = double.tryParse(data['pitch']?.toString() ?? '0.0') ?? 0.0;
                        final double roll = double.tryParse(data['roll']?.toString() ?? '0.0') ?? 0.0;
                        final double scale = double.tryParse(data['escala']?.toString() ?? '1.0') ?? 1.0;
                        final String dateRaw = data['fecha'] ?? '';
                        final String? imgBase64 = data['imagen_base64'];

                        String dateStr = '';
                        if (dateRaw.isNotEmpty) {
                          try {
                            final parsed = DateTime.parse(dateRaw);
                            dateStr = '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
                          } catch (_) {
                            dateStr = dateRaw;
                          }
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (imgBase64 != null && imgBase64.isNotEmpty)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.memory(
                                        base64Decode(imgBase64),
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.4),
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentOrange.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Escala: ${scale.toStringAsFixed(2)}x',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.screen_rotation_rounded, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            'P: ${pitch.toStringAsFixed(1)}° | R: ${roll.toStringAsFixed(1)}°',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prodName,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(color: AppTheme.textGray, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _borrarMedicion(docId),
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                                      tooltip: 'Eliminar Medición',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _borrarMedicion(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('ELIMINAR MEDICIÓN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text('¿Estás seguro de que deseas eliminar esta medición de tu bitácora?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('mediciones_ar').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medición eliminada de la bitácora.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  void _estimarMaterialesConIA() async {
    setState(() => _isEstimating = true);
    
    final double areaM2 = (_productScale * 8.5);
    final String areaStr = areaM2.toStringAsFixed(1);
    
    final prompt = 'Hola Asistente Técnico Aly. Estoy usando el Medidor Láser AR para medir una pared de obra. El área medida es de $areaStr metros cuadrados y planeo usar el nivelador de alineación "$_selectedProduct" para el tarrajeo y pintado. \n'
        'Calcula cuánto Cemento Portland Aly (código MC-CEME-001, precio S/ 28.50) y cuánta Silicona Aly (código AC-SILI-003, precio S/ 14.90) necesitaré para cubrir esta área. \n'
        'Por favor, estructúralo de forma amigable e indica las cantidades exactas a comprar.';

    try {
      final geminiService = GeminiService();
      final response = await geminiService.chat(history: [
        {'role': 'user', 'text': prompt}
      ]);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.accentOrange),
              SizedBox(width: 10),
              Text('CÁLCULO IA DE MATERIALES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basado en tu medición AR de $areaStr m²:',
                  style: const TextStyle(color: AppTheme.textGray, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  response,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: AppTheme.textGray)),
            ),
            ElevatedButton(
              onPressed: () {
                final cartNotifier = ref.read(cartProvider.notifier);
                
                final cemento = CatalogoProducto(
                  id: 'prod_cemento_aly',
                  nombre: 'Cemento Portland Extra Fuerte Aly',
                  descripcion: 'Cemento de alta resistencia y fraguado rápido.',
                  precioUnitario: 28.50,
                  precioMayorista: 26.00,
                  stockMinimo: 10,
                  imagenUrl: 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?q=80&w=400',
                  categoria: 'Materiales de Construcción',
                  subcategoria: 'Cemento',
                  marca: 'Aly Industrial',
                  codigoSku: 'MC-CEME-001',
                  unidad: 'bolsa',
                  tags: ['cemento', 'portland', 'construccion'],
                  disponible: true,
                  caracteristicas: ['Resistente al salitre', 'Fraguado rápido'],
                );

                cartNotifier.addItem(cemento);
                cartNotifier.addItem(cemento);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Materiales sugeridos agregados al carrito de compras!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('AÑADIR MATERIALES AL CARRITO'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error estimando materiales con IA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar con el Asistente IA en este momento.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEstimating = false);
    }
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
