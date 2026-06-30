import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/home_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/signup_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/password_recovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  final List<Map<String, String>> _roles = [
    {'id': 'comprador', 'label': 'CLIENTE', 'subtitle': 'Compras & Pedidos', 'icon': '🛒'},
    {'id': 'admin', 'label': 'ADMINISTRADOR', 'subtitle': 'Control Total del Sistema', 'icon': '🛡️'},
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('Soporte biométrico - disponible: $isAvailable, dispositivo compatible: $isDeviceSupported');
      
      if (isAvailable && isDeviceSupported) {
        final prefs = await SharedPreferences.getInstance();
        final hasEnabledBio = prefs.getBool('bio_enabled') ?? false;
        final identifier = prefs.getString('bio_identifier') ?? '';
        final password = prefs.getString('bio_password') ?? '';
        
        if (hasEnabledBio && identifier.isNotEmpty && password.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              _handleBiometricLogin();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error al verificar biometría: $e');
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentícate con tu huella para iniciar sesión rápidamente',
        biometricOnly: true,
        stickyAuth: true,
      );

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final identifier = prefs.getString('bio_identifier') ?? '';
        final password = prefs.getString('bio_password') ?? '';

        if (identifier.isNotEmpty && password.isNotEmpty) {
          setState(() {
            _idController.text = identifier;
            _passwordController.text = password;
            _isLoading = true;
          });
          final authService = ref.read(authServiceProvider);
          
          final user = await authService.signIn(identifier, password);
          if (user != null) {
            ref.read(authStateProvider.notifier).state = user;
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => CatalogoScreen(userRole: user.rol)),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credenciales biométricas inválidas o expiradas.')),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al autenticar por huella: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onBiometricPressed() async {
    if (kIsWeb) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Huella Dactilar', style: TextStyle(color: Colors.white)),
            content: const Text(
              'La autenticación biométrica no está disponible en entorno Web Chrome. Por favor, inicie sesión manualmente.',
              style: TextStyle(color: AppTheme.textGray),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido', style: TextStyle(color: AppTheme.accentOrange)),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isAvailable || !isDeviceSupported) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              title: const Text('Huella Dactilar', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Este dispositivo no cuenta con soporte para autenticación biométrica o no está configurada.',
                style: TextStyle(color: AppTheme.textGray),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido', style: TextStyle(color: AppTheme.accentOrange)),
                ),
              ],
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasEnabledBio = prefs.getBool('bio_enabled') ?? false;
      if (!hasEnabledBio) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              title: const Text('Huella Dactilar', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Inicia sesión manualmente por primera vez para activar el ingreso rápido con huella dactilar.',
                style: TextStyle(color: AppTheme.textGray),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido', style: TextStyle(color: AppTheme.accentOrange)),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _handleBiometricLogin();
    } catch (e) {
      debugPrint('Error en botón biométrico: $e');
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final authService = ref.read(authServiceProvider);
    final user = await authService.signIn(identifier, password);
    
    if (user != null) {
      // Guardar credenciales locales para biometría rápida
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bio_identifier', identifier);
        await prefs.setString('bio_password', password);
        await prefs.setString('bio_role', user.rol);
        if (!kIsWeb) {
          final isAvailable = await _localAuth.canCheckBiometrics;
          final isDeviceSupported = await _localAuth.isDeviceSupported();
          if (isAvailable && isDeviceSupported) {
            await prefs.setBool('bio_enabled', true);
            debugPrint('🔒 Seguridad: Huella biométrica activada automáticamente.');
          }
        }
      } catch (e) {
        debugPrint('Error guardando preferencias biométricas: $e');
      }

      // Actualizar el estado global
      ref.read(authStateProvider.notifier).state = user;
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CatalogoScreen(userRole: user.rol)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario o contraseña incorrectos.')),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: isWide 
            ? _buildSplitWebLayout(context)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryDark,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTopBranding(),
                        _buildLoginForm(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSplitWebLayout(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.primaryDark,
      child: Row(
        children: [
          // Left side: Company details
          Expanded(
            child: Container(
              color: AppTheme.surfaceDark,
              padding: const EdgeInsets.all(48),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo-validado.png',
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.business,
                          size: 100,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'COMERCIALIZADORA ALY',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PORTAL DE GESTIÓN SEGURA',
                        style: TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Column(
                          children: [
                            const Text(
                              'Comercializadora Aly se especializa en la distribución y comercialización de herramientas premium, abrasivos, consumibles de soldadura y materiales de construcción de alta calidad en toda la región central.',
                              style: TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 14,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: const Text(
                                'RUC de la Empresa: 10432247657',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
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
          ),
          // Right side: Credentials Form
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLoginForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBranding() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: AppTheme.accentOrange.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/logo-validado.png',
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 60, color: AppTheme.accentOrange),
          ),
          const SizedBox(height: 24),
          const Text(
            'COMERCIALIZADORA ALY',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'PORTAL DE GESTIÓN SEGURA',
            style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'INICIAR SESIÓN',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: 'IDENTIFICADOR (USUARIO O CORREO)',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'CLAVE DE SEGURIDAD',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('AUTENTICAR ACCESO'),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.accentOrange, size: 28),
                  onPressed: _isLoading ? null : _onBiometricPressed,
                  tooltip: 'Inicio rápido con huella dactilar',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  );
                },
                child: const Text(
                  'REGISTRARSE',
                  style: TextStyle(
                    color: AppTheme.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen()),
                  );
                },
                child: const Text(
                  '¿OLVIDASTE TU CLAVE?',
                  style: TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
