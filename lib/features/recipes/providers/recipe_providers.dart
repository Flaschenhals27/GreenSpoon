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
  ref.read(recipeOverridesProvider.notifier).clear();
  ref.invalidate(recipesProvider);
}

/// Generiert [count] alternative Rezepte für genau eine Mahlzeit
/// ("Frühstück" | "Mittag" | "Abend"). Wird vom Long-Press auf einer
/// Rezeptkarte genutzt, um diese Mahlzeit einzeln neu vorschlagen zu lassen.
///
/// autoDispose: Jedes Öffnen des Auswahl-Sheets generiert frisch; beim
/// Schließen wird der Provider verworfen.
final mealAlternativesProvider =
    FutureProvider.autoDispose.family<List<Recipe>, String>((ref, meal) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.generate(meal: meal, count: 3);
  // Sicherheitsnetz: nur Rezepte der angefragten Mahlzeit behalten.
  final filtered = recipes.where((r) => r.meal == meal).toList();
  return filtered.isNotEmpty ? filtered : recipes;
});

/// Hält die vom User über das Auswahl-Sheet gewählten Ersatz-Rezepte,
/// je Mahlzeit eines. Die Rezept-Liste im UI wird damit überlagert, ohne
/// den Cache anzufassen. Ein „Alle neu" leert diese Auswahl wieder.
class RecipeOverrides extends Notifier<Map<String, Recipe>> {
  @override
  Map<String, Recipe> build() => const {};

  void set(String meal, Recipe recipe) {
    state = {...state, meal: recipe};
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final recipeOverridesProvider =
    NotifierProvider<RecipeOverrides, Map<String, Recipe>>(
  RecipeOverrides.new,
);

/// Wird vom recipesProvider geworfen, wenn der Vorrat leer ist.
/// Das UI behandelt das nicht als Fehler, sondern als Empty-State.
class PantryEmptyException implements Exception {
  const PantryEmptyException();
  @override
  String toString() => 'PantryEmptyException';
}
