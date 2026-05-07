import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pantry_repository.dart';
import '../domain/pantry_item.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository();
});

/// Live-Stream aller Vorrats-Items des eingeloggten Users.
final pantryStreamProvider = StreamProvider<List<PantryItem>>((ref) {
  return ref.watch(pantryRepositoryProvider).watchAll();
});

/// Items, die in <= 3 Tagen ablaufen, sortiert nach Dringlichkeit.
final expiringSoonProvider = Provider<List<PantryItem>>((ref) {
  final all = ref.watch(pantryStreamProvider).valueOrNull ?? [];
  return all
      .where((p) {
        final d = p.daysUntilExpiry;
        return d != null && d <= 3;
      })
      .toList();
});