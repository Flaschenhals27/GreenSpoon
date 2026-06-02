import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/saved_recipe_repository.dart';
import '../domain/recipe.dart';

final savedRecipeRepositoryProvider =
    Provider<SavedRecipeRepository>((ref) => SavedRecipeRepository());

/// Liste der gespeicherten Rezepte (für eine evtl. Übersicht).
final savedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return ref.watch(savedRecipeRepositoryProvider).fetchAll();
});

/// Ob ein bestimmtes Rezept (per Titel) gespeichert ist.
final isRecipeSavedProvider =
    FutureProvider.family<bool, String>((ref, title) async {
  return ref.watch(savedRecipeRepositoryProvider).isSaved(title);
});
