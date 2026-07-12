import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../data/recipe_cache.dart';
import '../data/recipe_repository.dart';
import '../domain/meal.dart';
import '../domain/recipe.dart';
import 'recipe_cooldown_provider.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return SupabaseRecipeRepository(ref.watch(supabaseClientProvider));
});

final recipeCacheProvider = Provider<RecipeCache>((ref) {
  return RecipeCache(ref.watch(supabaseClientProvider));
});

/// Rezepte für den aktuellen Vorrat — aus dem [RecipeCache], solange sich
/// Tag/Vorrat/User nicht geändert haben; bei leerem Vorrat fliegt
/// [PantryEmptyException] (UI zeigt dann einen Empty-State).
final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  // Nur das Leer-Flag beobachten — normale Vorrats-Änderungen sollen keinen
  // teuren Generierungs-Lauf anstoßen.
  ref.watch(
    pantryStreamProvider.select((async) => async.valueOrNull?.isEmpty),
  );

  final pantry = await ref.read(pantryStreamProvider.future);
  if (pantry.isEmpty) {
    throw const PantryEmptyException();
  }

  final cache = ref.watch(recipeCacheProvider);
  final signature = cache.signatureFor(pantry);

  // Cache-Treffer (gleicher Tag + Vorrat) → ohne API-Call zurückgeben.
  final cached = await cache.load();
  if (cached != null &&
      cached.signature == signature &&
      cached.recipes.isNotEmpty) {
    return cached.recipes;
  }

  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.generate();
  await cache.save(recipes, signature);
  return recipes;
});

/// Erzwingt eine frische Generierung: Cache leeren, neu laden.
Future<void> refreshRecipes(WidgetRef ref) async {
  await ref.read(recipeCacheProvider).clear();
  ref.read(recipeOverridesProvider.notifier).clear();
  ref.invalidate(recipesProvider);
}

/// [refreshRecipes], sofern der Cooldown es erlaubt (alle Retry-Buttons).
void refreshRecipesIfAllowed(WidgetRef ref) {
  if (ref.read(recipeCooldownProvider.notifier).trigger()) {
    refreshRecipes(ref);
  }
}

/// [count] Alternativen für eine [Meal] (Long-Press auf einer Karte).
/// autoDispose: jedes Öffnen des Sheets generiert frisch.
final mealAlternativesProvider =
    FutureProvider.autoDispose.family<List<Recipe>, Meal>((ref, meal) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.generate(meal: meal, count: 3);
  // Sicherheitsnetz: nur Rezepte der angefragten Mahlzeit behalten.
  final filtered = recipes.where((r) => r.meal == meal).toList();
  return filtered.isNotEmpty ? filtered : recipes;
});

/// Vom User gewählte Ersatz-Rezepte (eines je Mahlzeit) — überlagern die
/// Liste, ohne den Cache anzufassen; „Alle neu" leert sie.
class RecipeOverrides extends Notifier<Map<Meal, Recipe>> {
  @override
  Map<Meal, Recipe> build() => const {};

  void set(Meal meal, Recipe recipe) {
    state = {...state, meal: recipe};
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final recipeOverridesProvider =
    NotifierProvider<RecipeOverrides, Map<Meal, Recipe>>(
  RecipeOverrides.new,
);

/// „Vorrat leer" — vom UI als Empty-State behandelt, nicht als Fehler.
class PantryEmptyException implements Exception {
  const PantryEmptyException();
  @override
  String toString() => 'PantryEmptyException';
}
