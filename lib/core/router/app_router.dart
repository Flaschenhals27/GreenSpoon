import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/shell/main_shell.dart';
import '../supabase/supabase_providers.dart';

/// Listenable, das go_router neu evaluiert, sobald Supabase einen
/// Auth-State-Change feuert (Login, Logout, Token-Refresh).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(SupabaseClient client) {
    _sub = client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final notifier = _AuthRefreshNotifier(client);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final goingToAuth = loc == '/login' || loc == '/signup';

      // Der Passwort-Reset bleibt immer erreichbar — auch während der
      // Recovery-Session (sonst würde der User vor dem Setzen des neuen
      // Passworts auf den Home-Screen umgeleitet).
      if (loc == '/reset-password') return null;

      if (!isLoggedIn && !goingToAuth) return '/login';
      if (isLoggedIn && goingToAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
    ],
  );
});
