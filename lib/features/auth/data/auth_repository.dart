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

  /// Schritt 1 des Passwort-Resets: schickt dem User eine Email mit einem
  /// 6-stelligen Code (kein Deep-Link nötig — siehe Setup-Hinweis).
  ///
  /// Damit die Mail den Code enthält, muss die Supabase-Vorlage
  /// „Reset Password" `{{ .Token }}` ausgeben.
  Future<void> sendPasswordResetCode(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Schritt 2: verifiziert den Code aus der Email. Bei Erfolg entsteht eine
  /// (Recovery-)Session, mit der das Passwort gesetzt werden darf.
  Future<AuthResponse> verifyPasswordResetCode({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  /// Schritt 3: setzt das neue Passwort für den (per Recovery-Session)
  /// eingeloggten User.
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Logout.
  Future<void> signOut() => _client.auth.signOut();
}
