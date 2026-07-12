import '../../pantry/domain/pantry_item.dart';

/// Erstes bald ablaufendes Item, das eine Rezept-Zutat [uses] verwertet
/// („Rettet …"-Hinweis). Bewusst unscharfes beidseitiges `contains`,
/// weil KI-Zutatennamen selten exakt den Vorratsnamen entsprechen.
PantryItem? findRescuedItem(List<PantryItem> expiring, List<String> uses) {
  for (final item in expiring) {
    final itemName = item.name.toLowerCase();
    for (final use in uses) {
      final useName = use.toLowerCase();
      if (useName.contains(itemName) || itemName.contains(useName)) {
        return item;
      }
    }
  }
  return null;
}
