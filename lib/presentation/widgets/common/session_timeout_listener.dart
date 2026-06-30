import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/settings_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/screens/login_screen.dart';
import 'package:gestor_invetarios_pedidos_app/main.dart';

class SessionTimeoutListener extends ConsumerStatefulWidget {
  final Widget child;
  const SessionTimeoutListener({super.key, required this.child});

  @override
  ConsumerState<SessionTimeoutListener> createState() => _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends ConsumerState<SessionTimeoutListener> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  static const Duration _timeoutDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndStartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }

  void _checkAndStartTimer() {
    final user = ref.read(authStateProvider);

    _cancelTimer();

    if (user == null) return;

    _inactivityTimer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _resetTimer() {
    final user = ref.read(authStateProvider);

    if (user == null) {
      _cancelTimer();
      return;
    }

    _cancelTimer();
    _inactivityTimer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _cancelTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _handleTimeout() {
    debugPrint('🔒 Seguridad: Sesión cerrada por inactividad (5 minutos)');
    _logout();
  }

  void _logout() async {
    final user = ref.read(authStateProvider);
    if (user == null) return;

    _cancelTimer();

    // Cerrar sesión
    await ref.read(authServiceProvider).signOut();
    ref.read(authStateProvider.notifier).state = null;

    // Redirigir al Login de forma global y segura
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Cierre de sesión por inactividad fijo, removemos el cierre al minimizar
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios para restablecer o limpiar el temporizador reactivamente
    ref.listen(authStateProvider, (previous, next) {
      _checkAndStartTimer();
    });

    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
