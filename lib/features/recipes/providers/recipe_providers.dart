import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/providers/pantry_providers.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository();
});

/// Lädt Rezepte einmalig. UI kann mit `ref.invalidate(recipesProvider)`
/// einen Reload erzwingen.
///
/// Wirft [PantryEmptyException] (statt einer normalen Exception), wenn
/// der Vorrat des Users leer ist — dann lohnt sich der API-Call nicht
/// und das UI zeigt einen passenden Empty-State.
final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  // Erst checken, ob der User überhaupt Vorrat hat.
  // Wir hören auf den Stream, lesen aber nur den aktuellen Wert.
  final pantry = await ref.read(pantryStreamProvider.future);
  if (pantry.isEmpty) {
    throw const PantryEmptyException();
  }

  final repo = ref.watch(recipeRepositoryProvider);
  return repo.generate();
});

/// Wird vom recipesProvider geworfen, wenn der Vorrat leer ist.
/// Das UI behandelt das nicht als Fehler, sondern als Empty-State.
class PantryEmptyException implements Exception {
  const PantryEmptyException();
  @override
  String toString() => 'PantryEmptyException';
}