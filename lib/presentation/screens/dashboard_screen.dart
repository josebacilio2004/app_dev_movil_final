import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/investor_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/buyer_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/mapa_ruta_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/admin_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/operator_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/buyer_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/investor_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/usuario.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);

    if (user == null) {
      return const LoginScreen();
    }

    final profile = {'id': user.id, 'nombre': user.nombre, 'usuario': user.usuario, 'rol': user.rol};

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'dashboard'),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange),
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
        iconTheme: const IconThemeData(color: AppTheme.accentOrange, size: 28),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textGray),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildDashboardSelector(context, user, ref),
    );
  }

  Widget _buildDashboardSelector(BuildContext context, Usuario user, WidgetRef ref) {
    String username = user.nombre;
    final role = user.rol.toLowerCase();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(username, role),
              const SizedBox(height: 32),
              _getDashboardWidget(user, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getDashboardWidget(Usuario user, WidgetRef ref) {
    final profile = {'id': user.id, 'nombre': user.nombre, 'rol': user.rol};
    switch (user.rol.toLowerCase()) {
      case 'admin': return AdminDashboard(profile: profile);
      case 'operador': return OperatorDashboard(profile: profile);
      case 'comprador': return BuyerDashboard(profile: profile);
      case 'inversionista': return InvestorDashboard(profile: profile);
      default: return OperatorDashboard(profile: profile);
    }
  }

  Widget _buildHeader(String name, String role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.accentOrange.withOpacity(0.2)),
          ),
          child: Text(
            role.toUpperCase(),
            style: const TextStyle(color: AppTheme.accentOrange, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const Text(
          'Sistema de Gestión Industrial Sincronizado.',
          style: TextStyle(color: AppTheme.textGray, fontSize: 13),
        ),
      ],
    );
  }
}
