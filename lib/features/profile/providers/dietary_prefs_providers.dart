import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dietary_prefs_repository.dart';

final dietaryPrefsRepositoryProvider =
    Provider<DietaryPrefsRepository>((ref) => DietaryPrefsRepository());

/// Aktuell gesetzte Diät-Tags.
final dietaryPrefsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(dietaryPrefsRepositoryProvider).fetch();
});