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

class WebSidebar extends ConsumerWidget {
  final String currentRoute;

  const WebSidebar({super.key, required this.currentRoute});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const SizedBox.shrink();

    final String role = user.rol.toLowerCase();
    final bool isAdmin = role == 'admin' || role == 'administrador';

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      child: Column(
        children: [
          // Header del Sidebar con el logo validado
          Container(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accentOrange.withOpacity(0.1), Colors.transparent],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo-validado.png',
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 56, color: AppTheme.accentOrange),
                ),
                const SizedBox(height: 12),
                Text(
                  'ALY INDUSTRIAL',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
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
                if (isAdmin) ...[
                  _sidebarItem(
                    context,
                    label: 'ESTADÍSTICAS (DASHBOARD)',
                    icon: Icons.analytics_rounded,
                    isSelected: currentRoute == 'dashboard',
                    onTap: () => _navigate(context, const DashboardScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'GESTIÓN DE PRODUCTOS',
                    icon: Icons.storefront_rounded,
                    isSelected: currentRoute == 'catalog',
                    onTap: () => _navigate(context, CatalogoScreen(userRole: role)),
                  ),
                  _sidebarItem(
                    context,
                    label: 'PEDIDOS & VENTAS',
                    icon: Icons.assignment_rounded,
                    isSelected: currentRoute == 'orders',
                    onTap: () => _navigate(context, const OrderListScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'BANDEJA DE AVISOS',
                    icon: Icons.notifications_rounded,
                    isSelected: currentRoute == 'notifications',
                    onTap: () => _navigate(context, const NotificationInboxScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'CONFIGURACIÓN',
                    icon: Icons.settings_rounded,
                    isSelected: currentRoute == 'settings',
                    onTap: () => _navigate(context, const SettingsScreen()),
                  ),
                ] else ...[
                  _sidebarItem(
                    context,
                    label: 'INICIO',
                    icon: Icons.home_rounded,
                    isSelected: currentRoute == 'home',
                    onTap: () => _navigate(context, const HomeScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'CATÁLOGO DE PRODUCTOS',
                    icon: Icons.storefront_rounded,
                    isSelected: currentRoute == 'catalog',
                    onTap: () => _navigate(context, CatalogoScreen(userRole: role)),
                  ),
                  _sidebarItem(
                    context,
                    label: 'MIS PEDIDOS',
                    icon: Icons.assignment_rounded,
                    isSelected: currentRoute == 'orders',
                    onTap: () => _navigate(context, const OrderListScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'MIS BOLETAS / FACTURAS',
                    icon: Icons.receipt_long_rounded,
                    isSelected: currentRoute == 'invoices',
                    onTap: () => _navigate(context, const BoletasScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'SEGUIMIENTO DE DELIVERY',
                    icon: Icons.local_shipping_rounded,
                    isSelected: currentRoute == 'delivery_tracking',
                    onTap: () => _navigate(context, const SeguimientoDeliveryScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'CÓMO LLEGAR A LA TIENDA',
                    icon: Icons.explore_rounded,
                    isSelected: currentRoute == 'gps',
                    onTap: () => _navigate(context, MapaRutaScreen(usuarioId: user.id)),
                  ),
                  _sidebarItem(
                    context,
                    label: 'NIVELADOR DIGITAL ALY',
                    icon: Icons.architecture_rounded,
                    isSelected: currentRoute == 'sensor_level',
                    onTap: () => _navigate(context, const SensorLevelScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'MEDIDOR LÁSER AR',
                    icon: Icons.photo_camera_rounded,
                    isSelected: currentRoute == 'ar_camera',
                    onTap: () => _navigate(context, const ArMeasurementScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'ASISTENTE TÉCNICO IA',
                    icon: Icons.chat_bubble_outline_rounded,
                    isSelected: currentRoute == 'gemini_chat',
                    onTap: () => _navigate(context, const GeminiChatScreen()),
                  ),
                  _sidebarItem(
                    context,
                    label: 'CONFIGURACIÓN',
                    icon: Icons.settings_rounded,
                    isSelected: currentRoute == 'settings',
                    onTap: () => _navigate(context, const SettingsScreen()),
                  ),
                ],
              ],
            ),
          ),

          // Perfil de Usuario y Cerrar Sesión
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.accentOrange.withOpacity(0.2),
                      radius: 18,
                      child: Text(
                        user.nombre.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nombre,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.usuario,
                            style: const TextStyle(color: AppTheme.textGray, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
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
                    icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.white),
                    label: const Text('CERRAR SESIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentOrange.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.accentOrange.withOpacity(0.2) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.accentOrange : AppTheme.textGray,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : AppTheme.textGray,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
