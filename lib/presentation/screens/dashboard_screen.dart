import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/investor_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/buyer_nav_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/catalogo_screen.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/admin_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/operator_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/buyer_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/dashboards/investor_dashboard.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/usuario.dart';

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
      drawer: _buildDrawer(context, ref, profile),
      appBar: AppBar(
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

  Widget _buildDrawer(BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    final buyerSection = ref.watch(buyerNavProvider);
    final investorSection = ref.watch(investorNavProvider);
    final String role = profile['rol']?.toString().toLowerCase() ?? 'comprador';

    return Drawer(
      backgroundColor: AppTheme.primaryDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accentOrange.withOpacity(0.1), AppTheme.primaryDark],
              ),
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
                  child: Image.asset('assets/logo_premium.png', height: 70),
                ),
                const SizedBox(height: 20),
                Text(
                  'COMERCIALIZADORA ALY',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (role == 'comprador') ...[
                  _drawerItem(ref, BuyerSection.dashboard, 'DASHBOARD', Icons.grid_view_rounded, buyerSection == BuyerSection.dashboard),
                  _drawerItem(ref, BuyerSection.orders, 'GESTIÓN DE PEDIDOS', Icons.assignment_rounded, buyerSection == BuyerSection.orders),
                  _drawerItem(ref, BuyerSection.myProducts, 'MIS PRODUCTOS', Icons.inventory_2_rounded, buyerSection == BuyerSection.myProducts),
                  _drawerItem(ref, BuyerSection.invoicing, 'FACTURACIÓN', Icons.account_balance_wallet_rounded, buyerSection == BuyerSection.invoicing),
                  _drawerItem(ref, BuyerSection.wholesaleSales, 'VENTAS MAYORISTAS', Icons.shopping_cart_rounded, buyerSection == BuyerSection.wholesaleSales),
                  const Divider(color: Colors.white12, height: 24),
                  _catalogDrawerItem(context, role),
                ] else if (role == 'inversionista') ...[
                  _drawerItem(ref, InvestorSection.dashboard, 'DASHBOARD', Icons.dashboard_rounded, investorSection == InvestorSection.dashboard),
                  _drawerItem(ref, InvestorSection.orders, 'MIS INVERSIONES', Icons.monetization_on_rounded, investorSection == InvestorSection.orders),
                  _drawerItem(ref, InvestorSection.products, 'PRODUCTOS', Icons.category_rounded, investorSection == InvestorSection.products),
                  _drawerItem(ref, InvestorSection.distributors, 'DISTRIBUIDORES', Icons.business_rounded, investorSection == InvestorSection.distributors),
                  _drawerItem(ref, InvestorSection.buyers, 'COMPRADORES', Icons.people_rounded, investorSection == InvestorSection.buyers),
                  const Divider(color: Colors.white12, height: 24),
                  _catalogDrawerItem(context, role),
                ] else if (role == 'admin') ...[
                  _catalogDrawerItem(context, role),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                ref.read(authStateProvider.notifier).state = null;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
              child: const Text('CERRAR SESIÓN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(WidgetRef ref, dynamic section, String label, IconData icon, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentOrange.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppTheme.accentOrange : AppTheme.textGray, size: 20),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textGray,
          ),
        ),
        onTap: () {
          if (section is BuyerSection) ref.read(buyerNavProvider.notifier).state = section;
          if (section is InvestorSection) ref.read(investorNavProvider.notifier).state = section;
          Navigator.pop(ref.context);
        },
      ),
    );
  }

  Widget _catalogDrawerItem(BuildContext context, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentOrange.withOpacity(0.08), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentOrange.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: const Icon(Icons.storefront_rounded, color: AppTheme.accentOrange, size: 20),
        title: Text(
          'CATÁLOGO DE PRODUCTOS',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.accentOrange,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.accentOrange),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CatalogoScreen(userRole: role),
            ),
          );
        },
      ),
    );
  }
}
