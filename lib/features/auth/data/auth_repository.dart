import 'package:supabase_flutter/supabase_flutter.dart';

/// Vertrag für das Auth-Backend.
///
/// UI- und Provider-Code hängen ausschließlich an dieser Abstraktion (DIP) —
/// sie kennen Supabase nicht direkt. Das macht Tests und einen späteren
/// Wechsel des Auth-Backends einfach.
abstract interface class AuthRepository {
  /// Aktueller User oder null, wenn nicht eingeloggt.
  User? get currentUser;

  /// Stream der Auth-Status-Änderungen.
  Stream<AuthState> authStateChanges();

  /// Email/Passwort-Login.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Email/Passwort-Registrierung.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Schickt dem User eine Email mit einem 6-stelligen Reset-Code.
  Future<void> sendPasswordResetCode(String email);

  /// Verifiziert den Code aus der Email und öffnet eine Recovery-Session.
  Future<AuthResponse> verifyPasswordResetCode({
    required String email,
    required String token,
  });

  /// Setzt das neue Passwort für den (per Recovery-Session) eingeloggten User.
  Future<UserResponse> updatePassword(String newPassword);

  /// Setzt den Anzeigenamen (User-Metadaten `display_name`).
  /// Leerer String entfernt den Namen wieder.
  Future<UserResponse> updateDisplayName(String name);

  /// Logout.
  Future<void> signOut();
}

/// Supabase-gestützte Umsetzung von [AuthRepository].
///
/// Alle Auth-Calls laufen ausschließlich hierüber. Der [SupabaseClient] wird
/// injiziert, statt auf das globale Singleton zuzugreifen.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Hinweis: Je nach Supabase-Projekteinstellung muss der User die Email
  /// bestätigen, bevor er sich einloggen kann (Default: an).
  @override
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
  @override
  Future<void> sendPasswordResetCode(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Schritt 2: verifiziert den Code aus der Email. Bei Erfolg entsteht eine
  /// (Recovery-)Session, mit der das Passwort gesetzt werden darf.
  @override
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
  @override
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<UserResponse> updateDisplayName(String name) {
    return _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
