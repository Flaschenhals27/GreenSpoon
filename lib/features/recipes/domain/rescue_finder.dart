import '../../pantry/domain/pantry_item.dart';
import 'ingredient_matcher.dart';

/// Erstes bald ablaufendes Item, das eine Rezept-Zutat [uses] verwertet
/// („Rettet …"-Hinweis). Unscharfes Matching siehe [ingredientMatchesItem].
PantryItem? findRescuedItem(List<PantryItem> expiring, List<String> uses) {
  for (final item in expiring) {
    for (final use in uses) {
      if (ingredientMatchesItem(use, item.name)) return item;
    }
  }
  return null;
}
