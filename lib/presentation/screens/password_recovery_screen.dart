import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace de recuperación enviado. Revisa tu bandeja de entrada.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(); // Retornar a Login
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar correo: $e'),
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
                        'RECUPERAR CONTRASEÑA',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa tu correo registrado y te enviaremos las instrucciones para restablecer tu clave de acceso.',
                        style: TextStyle(color: AppTheme.textGray, fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      
                      // Correo
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'CORREO ELECTRÓNICO REGISTRADO',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // Botón Enviar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleResetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('ENVIAR ENLACE DE RESTABLECIMIENTO'),
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
            'PORTAL DE RECUPERACIÓN DE CLAVES',
            style: TextStyle(color: AppTheme.textGray, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
