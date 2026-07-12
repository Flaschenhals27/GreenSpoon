import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/pantry_repository.dart';
import '../domain/pantry_item.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return SupabasePantryRepository(ref.watch(supabaseClientProvider));
});

/// Live-Stream aller Vorrats-Items des eingeloggten Users.
final pantryStreamProvider = StreamProvider<List<PantryItem>>((ref) {
  return ref.watch(pantryRepositoryProvider).watchAll();
});

/// Items, die bald ablaufen (siehe [PantryItem.isExpiringSoon]).
final expiringSoonProvider = Provider<List<PantryItem>>((ref) {
  final all = ref.watch(pantryStreamProvider).valueOrNull ?? [];
  return all.where((p) => p.isExpiringSoon).toList();
});
