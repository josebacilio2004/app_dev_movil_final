import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/notification_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/web_sidebar.dart';

class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  ConsumerState<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends ConsumerState<NotificationInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Forzar actualización de notificaciones desde SharedPreferences al abrir
    Future.microtask(() {
      ref.read(notificationHistoryProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationHistoryProvider);
    final bool isWeb = kIsWeb || MediaQuery.of(context).size.width >= 900;

    // Filtrar notificaciones por búsqueda
    final filteredNotifications = notifications.where((n) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
    }).toList();

    final appBar = AppBar(
      leading: isWeb
          ? null
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      title: Text(
        'BANDEJA DE AVISOS',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
      actions: [
        if (notifications.isNotEmpty)
          TextButton.icon(
            onPressed: () => _confirmClearAll(context),
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 18),
            label: Text(
              'VACIAR',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
    );

    final mainContent = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Barra de búsqueda
            _buildSearchBar(),
            
            Expanded(
              child: filteredNotifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final n = filteredNotifications[index];
                        return _buildNotificationCard(n);
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    if (isWeb) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Row(
          children: [
            const WebSidebar(currentRoute: 'notifications'),
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: appBar,
                body: mainContent,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        drawer: const AppDrawer(currentRoute: 'notifications'),
        appBar: appBar,
        body: mainContent,
      );
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: AppTheme.surfaceDark.withOpacity(0.3),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar notificaciones...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textGray),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textGray),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.surfaceDark,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.textGray,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? 'No hay notificaciones' 
                : 'No se encontraron resultados',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Las alertas de GPS, compras y FCM se guardarán aquí.'
                : 'Prueba a buscar con palabras clave diferentes.',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification n) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(n.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (!n.read) {
            ref.read(notificationHistoryProvider.notifier).markAsRead(n.id);
          }
        },
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de lectura (Punto naranja)
              Container(
                margin: const EdgeInsets.only(top: 4, right: 12),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: n.read ? Colors.transparent : AppTheme.accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: AppTheme.textGray, fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.body,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        title: Text(
          'Vaciar Notificaciones',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Está seguro de que desea eliminar todas las notificaciones del historial? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppTheme.textGray, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(notificationHistoryProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
