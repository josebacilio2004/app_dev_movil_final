import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/home_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/usuario.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Configurar controladores de animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Animación de pulso (Escala de 0.85 a 1.05 con efecto respiración)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.05).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_animationController);

    // Animación de rotación sutil (Un pequeño giro de 360 grados lento)
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    // Iniciar y repetir la animación
    _animationController.repeat();

    // Arrancar inicialización de datos y navegación diferida
    _startAppInitialization();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startAppInitialization() async {
    final stopwatch = Stopwatch()..start();

    // 1. Ejecutar el autologin en segundo plano
    Usuario? user;
    try {
      user = await ref.read(autoLoginProvider.future);
      debugPrint('🔄 tryAutoLogin resultado: ${user != null ? 'Sesión activa de ' + user.nombre : 'Sin sesión activa'}');
    } catch (e) {
      debugPrint('⚠️ Error en tryAutoLogin: $e');
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final int remainingDelay = 2500 - elapsedMs;

    // 2. Garantizar que la animación se reproduzca por al menos 2.5 segundos para no romper la experiencia premium
    if (remainingDelay > 0) {
      await Future.delayed(Duration(milliseconds: remainingDelay));
    }

    if (!mounted) return;

    // 3. Enrutamiento inteligente hacia la pantalla correspondiente
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            user != null ? CatalogoScreen(userRole: user.rol) : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo decorativo con gradiente traslúcido
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  AppTheme.accentOrange.withOpacity(0.08),
                  AppTheme.primaryDark,
                ],
              ),
            ),
          ),
          
          // Centro Branded
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * 2 * 3.1415926535,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/logo_premium.png',
                    height: 120,
                    width: 120,
                    color: AppTheme.accentOrange,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.business_center_rounded,
                      size: 100,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Texto de marca
                Text(
                  'COMERCIALIZADORA ALY',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ALINEACIÓN & LOGÍSTICA INDUSTRIAL',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textGray,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          
          // Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Versión 2.0 · Cargando entorno seguro',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
