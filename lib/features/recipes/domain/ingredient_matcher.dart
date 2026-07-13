import '../../pantry/domain/pantry_item.dart';

/// Unscharfer Vergleich zwischen KI-Zutat und Vorratsnamen: bewusst
/// beidseitiges `contains`, weil KI-Zutatennamen selten exakt den
/// Vorratsnamen entsprechen („Cherry-Tomaten" ↔ „Tomaten").
bool ingredientMatchesItem(String ingredient, String itemName) {
  final a = ingredient.trim().toLowerCase();
  final b = itemName.trim().toLowerCase();
  return a.contains(b) || b.contains(a);
}

/// Eine Rezept-Zutat mit dem Vorrats-Item, das sie abdeckt.
class IngredientMatch {
  const IngredientMatch({required this.ingredient, required this.item});

  final String ingredient;
  final PantryItem item;
}

/// Ergebnis von [matchIngredientsToPantry]: Treffer in Zutaten-Reihenfolge
/// plus die Zutaten, für die nichts im Vorrat gefunden wurde.
class IngredientMatchResult {
  const IngredientMatchResult({
    required this.matches,
    required this.unmatched,
  });

  final List<IngredientMatch> matches;
  final List<String> unmatched;
}

/// Matcht Rezept-Zutaten gegen den Vorrat: pro Zutat gewinnt ein exakter
/// Namens-Treffer vor dem unscharfen [ingredientMatchesItem]; jedes
/// Vorrats-Item wird höchstens einer Zutat zugeordnet.
IngredientMatchResult matchIngredientsToPantry(
  List<String> ingredients,
  List<PantryItem> pantry,
) {
  final usedIds = <String>{};
  final matches = <IngredientMatch>[];
  final unmatched = <String>[];

  PantryItem? findFor(String ingredient) {
    final wanted = ingredient.trim().toLowerCase();
    for (final item in pantry) {
      if (usedIds.contains(item.id)) continue;
      if (item.name.trim().toLowerCase() == wanted) return item;
    }
    for (final item in pantry) {
      if (usedIds.contains(item.id)) continue;
      if (ingredientMatchesItem(ingredient, item.name)) return item;
    }
    return null;
  }

  for (final ingredient in ingredients) {
    final match = findFor(ingredient);
    if (match != null) {
      usedIds.add(match.id);
      matches.add(IngredientMatch(ingredient: ingredient, item: match));
    } else {
      unmatched.add(ingredient);
    }
  }

  return IngredientMatchResult(matches: matches, unmatched: unmatched);
}
