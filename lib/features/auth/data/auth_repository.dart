import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// Repository, das Supabase-Auth kapselt.
///
/// Alle Auth-Calls laufen ausschließlich hierüber — UI- und Provider-Code
/// kennen Supabase nicht direkt. Das macht spätere Tests und einen Wechsel
/// des Auth-Backends einfacher.
class AuthRepository {
  AuthRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// Aktueller User oder null, wenn nicht eingeloggt.
  User? get currentUser => _client.auth.currentUser;

  /// Stream der Auth-Status-Änderungen.
  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  /// Email/Passwort-Login.
  ///
  /// Wirft [AuthException] mit lesbarer Message bei Fehlern.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Email/Passwort-Registrierung.
  ///
  /// Hinweis: Je nach Supabase-Projekteinstellung muss der User die Email
  /// bestätigen, bevor er sich einloggen kann (Default: an).
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  /// Logout.
  Future<void> signOut() => _client.auth.signOut();
}
