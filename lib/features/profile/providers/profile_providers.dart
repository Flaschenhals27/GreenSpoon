import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/data/pantry_repository.dart';
import '../../pantry/providers/pantry_providers.dart';

/// User-Stats werden bei jedem Vorrat-Update neu berechnet, indem wir
/// den pantryStreamProvider beobachten — bei Änderungen invalidieren
/// wir uns selbst implizit über `ref.watch`.
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  // pantryStreamProvider beobachten, damit Stats neu laden, wenn sich
  // der Vorrat ändert. Wir lesen den aktuellen Snapshot, ohne den Wert
  // weiter zu verarbeiten.
  ref.watch(pantryStreamProvider);

  final repo = ref.watch(pantryRepositoryProvider);
  return repo.fetchStats();
});
