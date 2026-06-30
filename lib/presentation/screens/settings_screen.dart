import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _bioSupported = false;
  bool _bioEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // La autenticación biométrica no es compatible con Web en local_auth
      if (kIsWeb) {
        setState(() {
          _bioSupported = false;
          _bioEnabled = false;
          _isLoading = false;
        });
        return;
      }

      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final bioEnabled = prefs.getBool('bio_enabled') ?? false;

      setState(() {
        _bioSupported = isAvailable && isDeviceSupported;
        _bioEnabled = bioEnabled;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando preferencias de configuración: $e');
      setState(() {
        _bioSupported = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (kIsWeb || !_bioSupported) return;

    try {
      // Si el usuario quiere activar la huella, solicitamos una autenticación de confirmación
      if (value) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirma tu huella para activar el acceso rápido biométrico',
        );

        if (!authenticated) {
          // El usuario canceló o falló la autenticación
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final bioId = prefs.getString('bio_identifier') ?? '';
        if (bioId.isEmpty) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Inicio con Huella', style: TextStyle(color: Colors.white)),
                content: const Text(
                  'Para activar la huella, primero debes iniciar sesión manualmente con tu contraseña al menos una vez para guardar tus credenciales de forma segura en este dispositivo.',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 13),
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
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bio_enabled', value);
      setState(() {
        _bioEnabled = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
                ? 'Acceso rápido con huella dactilar activado.' 
                : 'Acceso rápido con huella dactilar desactivado.'
            ),
            backgroundColor: value ? AppTheme.successGreen : AppTheme.surfaceDark,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al configurar biometría: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al configurar huella: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = cs.surface;
    final onSurfaceColor = cs.onSurface;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;
    final subtitleColor = isDark ? AppTheme.textGray : const Color(0xFF64748B);

    final appBar = AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'CONFIGURACIÓN',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1.5,
          color: onSurfaceColor,
        ),
      ),
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: dividerColor, width: 1)),
    );

    final mainContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
        : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREFERENCIAS DE SEGURIDAD',
                        style: GoogleFonts.outfit(
                          color: subtitleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.fingerprint_rounded,
                                      color: AppTheme.accentOrange,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Acceso con Huella Dactilar',
                                          style: GoogleFonts.outfit(
                                            color: onSurfaceColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Permite iniciar sesión con biometría.',
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                   value: _bioEnabled,
                                   onChanged: (kIsWeb || !_bioSupported) 
                                       ? null 
                                       : _toggleBiometrics,
                                   activeColor: AppTheme.accentOrange,
                                   activeTrackColor: AppTheme.accentOrange.withOpacity(0.3),
                                   inactiveThumbColor: subtitleColor,
                                   inactiveTrackColor: cs.surfaceContainerHighest,
                                 ),
                              ],
                            ),
                            
                            // Mensaje descriptivo / Advertencia
                            if (kIsWeb) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Divider(color: dividerColor),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: subtitleColor, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'La autenticación biométrica (local_auth) no está disponible en entornos de navegador web Chrome. Utilice un dispositivo móvil Android compatible.',
                                      style: TextStyle(
                                        color: Colors.amber.withOpacity(0.8),
                                        fontSize: 9,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (!_bioSupported) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Divider(color: dividerColor),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tu dispositivo no cuenta con sensor de huella dactilar configurado o compatible con la aplicación.',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 9,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text(
                        'PREFERENCIAS DE INTERFAZ Y ALERTAS',
                        style: GoogleFonts.outfit(
                          color: subtitleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fila de cambiar Tema claro/oscuro
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.palette_rounded,
                                      color: AppTheme.accentOrange,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tema Claro (Light Mode)',
                                          style: GoogleFonts.outfit(
                                            color: onSurfaceColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Activa el tema de diseño claro.',
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                   value: ref.watch(themeModeProvider) == ThemeMode.light,
                                   onChanged: (isLight) {
                                     ref.read(themeModeProvider.notifier).toggleTheme(isLight);
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text(isLight ? 'Tema Claro activado.' : 'Tema Oscuro activado.'),
                                         backgroundColor: AppTheme.successGreen,
                                         duration: const Duration(seconds: 1),
                                       ),
                                     );
                                   },
                                   activeColor: AppTheme.accentOrange,
                                   activeTrackColor: AppTheme.accentOrange.withOpacity(0.3),
                                   inactiveThumbColor: subtitleColor,
                                   inactiveTrackColor: cs.surfaceContainerHighest,
                                 ),
                              ],
                            ),
                            
                             Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: dividerColor),
                            ),

                            // Fila de notificaciones habilitadas/deshabilitadas
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.notifications_active_rounded,
                                      color: AppTheme.accentOrange,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notificaciones de la App',
                                          style: GoogleFonts.outfit(
                                            color: onSurfaceColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Activa o desactiva alertas del sistema.',
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                   value: ref.watch(notificationsEnabledProvider),
                                   onChanged: (enabled) {
                                     ref.read(notificationsEnabledProvider.notifier).toggleNotifications(enabled);
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text(enabled ? 'Notificaciones activadas.' : 'Notificaciones desactivadas.'),
                                         backgroundColor: AppTheme.successGreen,
                                         duration: const Duration(seconds: 1),
                                       ),
                                     );
                                   },
                                   activeColor: AppTheme.accentOrange,
                                   activeTrackColor: AppTheme.accentOrange.withOpacity(0.3),
                                   inactiveThumbColor: subtitleColor,
                                   inactiveTrackColor: cs.surfaceContainerHighest,
                                 ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                 ),
              ),
            );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(currentRoute: 'settings'),
      appBar: appBar,
      body: mainContent,
    );
  }
}
