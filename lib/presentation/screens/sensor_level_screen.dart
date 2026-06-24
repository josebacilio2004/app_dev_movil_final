import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';

class SensorLevelScreen extends StatefulWidget {
  const SensorLevelScreen({super.key});

  @override
  State<SensorLevelScreen> createState() => _SensorLevelScreenState();
}

class _SensorLevelScreenState extends State<SensorLevelScreen> {
  StreamSubscription? _accelerometerSubscription;
  
  // Ángulos calculados
  double _pitch = 0.0; // Inclinación adelante/atrás (Eje Y)
  double _roll = 0.0;  // Inclinación izquierda/derecha (Eje X)

  // Posición de la burbuja en la pantalla (offset relativo de -1.0 a 1.0)
  double _bubbleX = 0.0;
  double _bubbleY = 0.0;

  bool _isAligned = false;
  bool _hasHapticFeedbackFired = false;
  bool _useSimulation = kIsWeb;
  String _sensorErrorMessage = '';

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
          // Filtrado básico/suavizado complementario
          // Aceleración de gravedad estándar es ~9.8 m/s²
          double x = event.x;
          double y = event.y;
          double z = event.z;

          // Calcular ángulos en grados
          // Eje Y (Pitch) e Eje X (Roll)
          double pitchVal = atan2(y, z) * 180 / pi;
          double rollVal = atan2(-x, sqrt(y * y + z * z)) * 180 / pi;

          // Mapear los valores de aceleración directamente al rango de pantalla [-1.0, 1.0]
          // Limitar a una inclinación máxima de ~45 grados para máxima precisión en planos
          double bx = (-x / 7.0).clamp(-1.0, 1.0);
          double by = (y / 7.0).clamp(-1.0, 1.0);

          if (mounted) {
            setState(() {
              _pitch = pitchVal;
              _roll = rollVal;
              _bubbleX = bx;
              _bubbleY = by;
              
              // Alineación perfecta dentro de un umbral de 0.8 grados en ambos ejes
              _isAligned = _pitch.abs() < 0.8 && _roll.abs() < 0.8;
              
              if (_isAligned) {
                if (!_hasHapticFeedbackFired) {
                  HapticFeedback.mediumImpact();
                  _hasHapticFeedbackFired = true;
                }
              } else {
                _hasHapticFeedbackFired = false;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Error en acelerómetro físico: $error');
          setState(() {
            _useSimulation = true;
            _sensorErrorMessage = 'Sensores físicos no disponibles en este entorno.';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _useSimulation = true;
        _sensorErrorMessage = 'No se pudo inicializar el acelerómetro.';
      });
    }
  }

  // Permite simular la inclinación usando gestos de arrastre en la cuadrícula (ideal para Web o Emulador)
  void _handleSimulationDrag(DragUpdateDetails details, Size containerSize) {
    if (!_useSimulation) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Calcular posición central de la cuadrícula
    final double centerX = containerSize.width / 2;
    final double centerY = containerSize.height / 2;

    // Calcular distancia relativa desde el centro (-1.0 a 1.0)
    // El radio máximo de arrastre está limitado al círculo exterior (~140px)
    double rx = (localPosition.dx - centerX) / 140;
    double ry = (localPosition.dy - centerY) / 140;

    // Ajustar origen si el arrastre se sale del plano circular
    double distance = sqrt(rx * rx + ry * ry);
    if (distance > 1.0) {
      rx /= distance;
      ry /= distance;
    }

    setState(() {
      _bubbleX = rx;
      _bubbleY = ry;
      
      // Simular ángulos correspondientes basados en el desplazamiento
      _pitch = _bubbleY * 15.0; // simular hasta 15 grados de inclinación
      _roll = _bubbleX * 15.0;

      _isAligned = _pitch.abs() < 0.8 && _roll.abs() < 0.8;
      
      if (_isAligned) {
        if (!_hasHapticFeedbackFired) {
          HapticFeedback.lightImpact();
          _hasHapticFeedbackFired = true;
        }
      } else {
        _hasHapticFeedbackFired = false;
      }
    });
  }

  void _resetSimulation() {
    if (!_useSimulation) return;
    setState(() {
      _bubbleX = 0.0;
      _bubbleY = 0.0;
      _pitch = 0.0;
      _roll = 0.0;
      _isAligned = true;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final Size containerSize = const Size(300, 300);
    final themeColor = _isAligned ? AppTheme.successGreen : AppTheme.accentOrange;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'sensor_level'),
      appBar: AppBar(
        title: Text(
          'NIVELADOR DIGITAL INDUSTRIAL',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Cabecera descriptiva
                _buildHeaderCard(),
                const SizedBox(height: 24),

                // Cuadrícula y Burbuja de Nivel
                GestureDetector(
                  onPanUpdate: (details) => _handleSimulationDrag(details, containerSize),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Anillos concéntricos del nivel
                      _buildLevelTarget(containerSize, themeColor),

                      // Burbuja de nivelación móvil
                      _buildMovingBubble(containerSize, themeColor),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Lectura digital de ángulos (Pitch / Roll)
                _buildAngleReadout(themeColor),
                const SizedBox(height: 24),

                // Botones / Informativos de simulación
                _buildSimulationFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.architecture_rounded, color: AppTheme.accentOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HERRAMIENTA NIVEL ALY',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Coloque el dispositivo plano sobre la superficie para medir la alineación. El nivel se activará en verde cuando esté alineado.',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTarget(Size size, Color themeColor) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: themeColor.withOpacity(0.3), width: 2),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Círculo exterior (Medio)
            Container(
              width: size.width * 0.65,
              height: size.height * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
            ),
            // Círculo de alineación perfecta (Centro)
            Container(
              width: size.width * 0.28,
              height: size.height * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: themeColor.withOpacity(0.6), width: 2),
                color: _isAligned ? themeColor.withOpacity(0.08) : Colors.transparent,
              ),
            ),
            // Cruz de centrado (Ejes X / Y)
            Container(
              width: 1.5,
              height: size.height - 40,
              color: Colors.white.withOpacity(0.04),
            ),
            Container(
              width: size.width - 40,
              height: 1.5,
              color: Colors.white.withOpacity(0.04),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovingBubble(Size size, Color themeColor) {
    // Escalar desplazamiento de [-1.0, 1.0] a píxeles
    // El radio máximo de la burbuja desde el centro es de aproximadamente 110px para no salirse del borde exterior
    final double radiusLimit = 110.0;
    final double dx = _bubbleX * radiusLimit;
    final double dy = _bubbleY * radiusLimit;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50), // Pequeño delay de suavizado físico
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: themeColor.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.9,
            colors: [
              Colors.white.withOpacity(0.6),
              themeColor,
              themeColor.withOpacity(0.8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAngleReadout(Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _angleColumn('INCLINACIÓN X (ROLL)', '${_roll.toStringAsFixed(1)}°', Icons.swap_horiz_rounded),
          _angleColumn('INCLINACIÓN Y (PITCH)', '${_pitch.toStringAsFixed(1)}°', Icons.swap_vert_rounded),
        ],
      ),
    );
  }

  Widget _angleColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.textGray, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textGray, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSimulationFooter() {
    if (_useSimulation) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mouse_rounded, color: AppTheme.accentOrange, size: 14),
              const SizedBox(width: 8),
              Text(
                'SIMULADOR DE ORIENTACIÓN ACTIVO',
                style: GoogleFonts.outfit(
                  color: AppTheme.accentOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _sensorErrorMessage.isNotEmpty 
                ? _sensorErrorMessage 
                : 'Arrastra el cursor sobre el nivel para simular inclinación física.',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 9),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _resetSimulation,
            icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
            label: const Text('CENTRAR NIVEL (0.0°)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.04),
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: Colors.white10),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sensors_rounded, color: AppTheme.successGreen, size: 14),
        const SizedBox(width: 8),
        Text(
          'SENSORES DE HARDWARE FUNCIONANDO',
          style: GoogleFonts.outfit(
            color: AppTheme.successGreen,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
