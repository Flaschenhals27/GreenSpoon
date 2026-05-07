import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Stellt das Repository zur Verfügung.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream des aktuellen Auth-Status.
///
/// Liefert `AuthState` (mit `event` und `session`). Konsumenten interessieren
/// sich meist nur für `session?.user` — siehe [currentUserProvider].
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Aktueller User oder null. Synchron lesbar für Auth-Guards im Router.
final currentUserProvider = Provider<User?>((ref) {
  // Auf den Stream reagieren, aber synchron den aktuellen User liefern.
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

/// `true`, wenn ein User eingeloggt ist.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
