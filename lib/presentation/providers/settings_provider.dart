import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AutoLogoutPolicy {
  inactivity, // 5 min of inactivity
  minimize,   // on minimize
  both,       // both
  disabled    // disabled
}

class AutoLogoutPolicyNotifier extends StateNotifier<AutoLogoutPolicy> {
  AutoLogoutPolicyNotifier() : super(AutoLogoutPolicy.inactivity) {
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('auto_logout_policy') ?? 'inactivity';
      state = _parsePolicy(saved);
    } catch (_) {}
  }

  AutoLogoutPolicy _parsePolicy(String val) {
    switch (val) {
      case 'minimize':
        return AutoLogoutPolicy.minimize;
      case 'both':
        return AutoLogoutPolicy.both;
      case 'disabled':
        return AutoLogoutPolicy.disabled;
      case 'inactivity':
      default:
        return AutoLogoutPolicy.inactivity;
    }
  }

  Future<void> setPolicy(AutoLogoutPolicy policy) async {
    state = policy;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_logout_policy', policy.name);
    } catch (_) {}
  }
}

final autoLogoutPolicyProvider = StateNotifierProvider<AutoLogoutPolicyNotifier, AutoLogoutPolicy>((ref) {
  return AutoLogoutPolicyNotifier();
});
