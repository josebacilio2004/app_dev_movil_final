import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/mapa_ruta_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/boletas_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/order_list_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/dashboard_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/notification_inbox_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/connection_status_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);

    if (user == null) {
      return const SizedBox.shrink();
    }

    final String name = user.nombre;
    final String role = user.rol.toLowerCase();

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'home'),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
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
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, color: AppTheme.accentOrange),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ALY INDUSTRIAL',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        centerTitle: false,
        actions: [
          const ConnectionStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: AppTheme.accentOrange, size: 24),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
              );
            },
            tooltip: 'Ver Notificaciones',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner de Bienvenida Glassmórfico
                _buildWelcomeBanner(name, user.rol),
                const SizedBox(height: 32),
                
                // Título de sección
                Text(
                  'MÓDULOS DE GESTIÓN OPERATIVA',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textGray,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de Accesos Rápidos
                _buildModulesGrid(context, role, user.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String name, String role) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accentOrange.withOpacity(0.2)),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accentOrange,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¡Bienvenido de vuelta,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Navega directamente a los módulos o utiliza el menú lateral izquierdo para acceder a todas las opciones.',
                  style: TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Icono grande de bienvenida
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '🏭',
                style: TextStyle(fontSize: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context, String role, String userId) {
    final List<Map<String, dynamic>> modules = [
      {
        'title': 'CATÁLOGO DE PRODUCTOS',
        'subtitle': 'Ventas y catálogo interactivo',
        'icon': Icons.storefront_rounded,
        'screen': CatalogoScreen(userRole: role),
        'emoji': '🛍️',
      },
      {
        'title': 'LOGÍSTICA DE ARRIBO',
        'subtitle': 'Ruta satelital y GPS de arribo',
        'icon': Icons.explore_rounded,
        'screen': MapaRutaScreen(usuarioId: userId),
        'emoji': '🗺️',
      },
      {
        'title': 'MIS BOLETAS / FACTURAS',
        'subtitle': 'Historial de comprobantes PDF',
        'icon': Icons.receipt_long_rounded,
        'screen': const BoletasScreen(),
        'emoji': '📄',
      },
      {
        'title': 'MIS PEDIDOS',
        'subtitle': 'Estado de tus órdenes actuales',
        'icon': Icons.assignment_rounded,
        'screen': const OrderListScreen(),
        'emoji': '📦',
      },
      {
        'title': 'ESTADÍSTICAS Y GRÁFICOS',
        'subtitle': 'Dashboard analítico del rol',
        'icon': Icons.analytics_rounded,
        'screen': const DashboardScreen(),
        'emoji': '📈',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final m = modules[index];
        return _buildModuleCard(context, m);
      },
    );
  }

  Widget _buildModuleCard(BuildContext context, Map<String, dynamic> m) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => m['screen'] as Widget),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    m['icon'] as IconData,
                    color: AppTheme.accentOrange,
                    size: 20,
                  ),
                ),
                Text(
                  m['emoji'] as String,
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    m['title'] as String,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['subtitle'] as String,
                    style: const TextStyle(
                      color: AppTheme.textGray,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
