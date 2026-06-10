import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/connection_provider.dart';

class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectionProvider);

    return Tooltip(
      message: isOnline ? 'Sincronizado con Firestore (Online)' : 'Modo Offline persistente activo',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOnline 
              ? AppTheme.successGreen.withOpacity(0.1) 
              : Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline 
                ? AppTheme.successGreen.withOpacity(0.3) 
                : Colors.redAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(isOnline: isOnline),
            const SizedBox(width: 6),
            Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: isOnline ? AppTheme.successGreen : Colors.redAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool isOnline;
  const _PulsingDot({required this.isOnline});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? AppTheme.successGreen : Colors.redAccent;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ],
        ),
      ),
    );
  }
}
