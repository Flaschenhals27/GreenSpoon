import '../../pantry/domain/pantry_item.dart';

/// Findet das erste bald ablaufende Vorrats-Item, das eine der
/// Rezept-Zutaten [uses] verwertet — Grundlage für den „Rettet …"-Hinweis
/// auf Rezeptkarten.
///
/// Der Abgleich ist bewusst unscharf (beidseitiges `contains`), weil die
/// KI-generierten Zutatennamen selten exakt den Vorratsnamen entsprechen
/// („Tomaten" vs. „Cherry-Tomaten").
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
