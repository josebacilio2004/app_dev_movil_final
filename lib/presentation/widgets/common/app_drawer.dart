import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/home_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/mapa_ruta_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/dashboard_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/boletas_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/order_list_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/notification_inbox_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/settings_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/seguimiento_delivery_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/sensor_level_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/ar_measurement_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/gemini_chat_screen.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const SizedBox.shrink();

    final String role = user.rol.toLowerCase();

    return Drawer(
      backgroundColor: AppTheme.primaryDark,
      child: Column(
        children: [
          // Header del Drawer
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accentOrange.withOpacity(0.15), AppTheme.primaryDark],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo_premium.png',
                  height: 64,
                  color: AppTheme.accentOrange,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 16),
                Text(
                  'ALY INDUSTRIAL',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                  ),
                  child: Text(
                    user.rol.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accentOrange,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items de Navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _drawerItem(
                  context,
                  label: 'INICIO',
                  icon: Icons.home_rounded,
                  isSelected: currentRoute == 'home',
                  onTap: () => _navigate(context, const HomeScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'CATÁLOGO DE PRODUCTOS',
                  icon: Icons.storefront_rounded,
                  isSelected: currentRoute == 'catalog',
                  onTap: () => _navigate(context, CatalogoScreen(userRole: role)),
                ),
                _drawerItem(
                  context,
                  label: 'LOGÍSTICA DE ARRIBO (GPS)',
                  icon: Icons.explore_rounded,
                  isSelected: currentRoute == 'gps',
                  onTap: () => _navigate(context, MapaRutaScreen(usuarioId: user.id)),
                ),
                _drawerItem(
                  context,
                  label: 'MIS BOLETAS / FACTURAS',
                  icon: Icons.receipt_long_rounded,
                  isSelected: currentRoute == 'invoices',
                  onTap: () => _navigate(context, const BoletasScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'SEGUIMIENTO DE DELIVERY',
                  icon: Icons.local_shipping_rounded,
                  isSelected: currentRoute == 'delivery_tracking',
                  onTap: () => _navigate(context, const SeguimientoDeliveryScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'NIVELADOR DIGITAL ALY',
                  icon: Icons.architecture_rounded,
                  isSelected: currentRoute == 'sensor_level',
                  onTap: () => _navigate(context, const SensorLevelScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'MEDIDOR LÁSER AR',
                  icon: Icons.photo_camera_rounded,
                  isSelected: currentRoute == 'ar_camera',
                  onTap: () => _navigate(context, const ArMeasurementScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'ASISTENTE TÉCNICO IA',
                  icon: Icons.chat_bubble_outline_rounded,
                  isSelected: currentRoute == 'gemini_chat',
                  onTap: () => _navigate(context, const GeminiChatScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'BANDEJA DE NOTIFICACIONES',
                  icon: Icons.notifications_rounded,
                  isSelected: currentRoute == 'notifications',
                  onTap: () => _navigate(context, const NotificationInboxScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'MIS PEDIDOS',
                  icon: Icons.assignment_rounded,
                  isSelected: currentRoute == 'orders',
                  onTap: () => _navigate(context, const OrderListScreen()),
                ),
                _drawerItem(
                  context,
                  label: 'CONFIGURACIÓN',
                  icon: Icons.settings_rounded,
                  isSelected: currentRoute == 'settings',
                  onTap: () => _navigate(context, const SettingsScreen()),
                ),
                
                // Mostrar Dashboard según rol (admin, operador, comprador, inversionista)
                _drawerItem(
                  context,
                  label: 'ESTADÍSTICAS (DASHBOARD)',
                  icon: Icons.analytics_rounded,
                  isSelected: currentRoute == 'dashboard',
                  onTap: () => _navigate(context, const DashboardScreen()),
                ),
              ],
            ),
          ),

          // Botón de Cerrar Sesión
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                ref.read(authStateProvider.notifier).state = null;
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentOrange.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
            ? Border.all(color: AppTheme.accentOrange.withOpacity(0.2)) 
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.accentOrange : AppTheme.textGray,
          size: 20,
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textGray,
            letterSpacing: 0.5,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigate(BuildContext context, Widget targetScreen) {
    Navigator.of(context).pop(); // Cerrar drawer
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }
}
