import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/providers/pantry_providers.dart';
import '../data/recipe_cache.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository();
});

/// Liefert die Rezepte für den aktuellen Vorrat.
///
/// Greift zuerst auf den persistenten [RecipeCache] zu, damit nicht bei jedem
/// App-Start erneut die Edge Function aufgerufen wird. Nur wenn sich Tag,
/// Vorrat oder User geändert haben (= andere Signatur) wird frisch generiert.
/// Ein manueller Reload läuft über [refreshRecipes].
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

  final signature = RecipeCache.signatureFor(pantry);

  // Cache-Treffer (gleicher Tag + Vorrat) → ohne API-Call zurückgeben.
  final cached = await RecipeCache.load();
  if (cached != null &&
      cached.signature == signature &&
      cached.recipes.isNotEmpty) {
    return cached.recipes;
  }

  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.generate();
  await RecipeCache.save(recipes, signature);
  return recipes;
});

/// Erzwingt eine frische Rezept-Generierung: leert den Cache und lädt neu.
/// Wird von den Refresh-/Retry-Aktionen im UI genutzt.
Future<void> refreshRecipes(WidgetRef ref) async {
  await RecipeCache.clear();
  ref.invalidate(recipesProvider);
}

/// Wird vom recipesProvider geworfen, wenn der Vorrat leer ist.
/// Das UI behandelt das nicht als Fehler, sondern als Empty-State.
class PantryEmptyException implements Exception {
  const PantryEmptyException();
  @override
  String toString() => 'PantryEmptyException';
}