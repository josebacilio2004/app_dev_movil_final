import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/reniec_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'comprador';
  bool _isQueryingDni = false;
  bool _isLoading = false;
  final ReniecService _reniecService = ReniecService();

  final List<Map<String, String>> _roles = [
    {'id': 'comprador', 'label': 'COMPRADOR'},
    {'id': 'operador', 'label': 'OPERADOR'},
    {'id': 'inversionista', 'label': 'INVERSIONISTA'},
    {'id': 'admin', 'label': 'ADMINISTRADOR'},
  ];

  @override
  void dispose() {
    _dniController.dispose();
    _nombreController.dispose();
    _usuarioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _consultarDni() async {
    final dni = _dniController.text.trim();
    if (dni.length != 8 || int.tryParse(dni) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un DNI válido de 8 dígitos.')),
      );
      return;
    }

    setState(() => _isQueryingDni = true);

    try {
      final resultado = await _reniecService.consultarDNI(dni);
      if (resultado != null && resultado.nombreCompleto.isNotEmpty) {
        setState(() {
          _nombreController.text = resultado.nombreCompleto;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DNI verificado con éxito.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DNI no encontrado o error en la consulta.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar DNI: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isQueryingDni = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nombre: _nombreController.text.trim(),
        usuario: _usuarioController.text.trim(),
        rol: _selectedRole,
        dni: _dniController.text.trim(),
      );

      if (user != null) {
        ref.read(authStateProvider.notifier).state = user;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada correctamente!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          Navigator.of(context).pop(); // Retornar a Login
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el registro: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Container(
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
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.accentOrange),
                          ),
                          const Text(
                            'RETORNAR',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.accentOrange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'CREAR NUEVA CUENTA',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // DNI Input con botón consultar
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dniController,
                              keyboardType: TextInputType.number,
                              maxLength: 8,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'DNI (RENIEC)',
                                prefixIcon: Icon(Icons.badge_outlined),
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if (v.length != 8) return 'Debe tener 8 dígitos';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 52,
                            width: 80,
                            margin: const EdgeInsets.only(top: 4),
                            child: ElevatedButton(
                              onPressed: _isQueryingDni ? null : _consultarDni,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                                foregroundColor: AppTheme.accentOrange,
                                side: BorderSide(color: AppTheme.accentOrange.withOpacity(0.3)),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isQueryingDni
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: AppTheme.accentOrange, strokeWidth: 2),
                                    )
                                  : const Text('RENIEC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Nombre Completo
                      TextFormField(
                        controller: _nombreController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'NOMBRE COMPLETO',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      // Usuario
                      TextFormField(
                        controller: _usuarioController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'NOMBRE DE USUARIO',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Correo
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'CORREO ELECTRÓNICO',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'CONTRASEÑA',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Selección de Rol
                      const Text(
                        'SELECCIONA TU ROL DE ACCESO',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.textGray),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceDark,
                            iconEnabledColor: AppTheme.accentOrange,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            items: _roles.map((r) => DropdownMenuItem<String>(
                              value: r['id'],
                              child: Text(r['label']!),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedRole = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Botón Registrar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('CREAR CUENTA NUEVA'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBranding() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: AppTheme.accentOrange.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              1, 0, 0, 0, 0,
              0, 1, 0, 0, 0,
              0, 0, 1, 0, 0,
              -1, -1, -1, 1, 255,
            ]),
            child: Image.asset(
              'assets/logo_premium.png',
              height: 60,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 50, color: AppTheme.accentOrange),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'REGISTRO DE CLIENTES & PERSONAL',
            style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
