/// Filter- und Gruppier-Logik der Vorratsliste — reine Funktionen ohne
/// UI-Abhängigkeiten, damit sie testbar bleiben und der Screen schlank.
library;

import 'pantry_item.dart';

/// Pseudo-Filter neben den echten Kategorien.
const String kPantryFilterAll = 'Alle';
const String kPantryFilterExpiringSoon = 'Läuft bald ab';

/// Wendet Kategorie-/Ablauf-Filter und Suchbegriff (Name oder Marke,
/// case-insensitiv) auf [items] an.
List<PantryItem> filterPantryItems(
  List<PantryItem> items, {
  required String filter,
  String query = '',
}) {
  var result = items;
  if (filter == kPantryFilterExpiringSoon) {
    result = result.where((p) => p.isExpiringSoon).toList();
  } else if (filter != kPantryFilterAll) {
    result = result.where((p) => p.category == filter).toList();
  }
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.brand?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
  return result;
}

/// Frische-Gruppen für die Anzeige: bald fällig (≤ 3 Tage), innerhalb von
/// zwei Wochen, länger haltbar (inkl. Items ohne MHD).
({
  List<PantryItem> soon,
  List<PantryItem> week,
  List<PantryItem> later,
}) groupByFreshness(List<PantryItem> items) {
  final soon = <PantryItem>[];
  final week = <PantryItem>[];
  final later = <PantryItem>[];
  for (final p in items) {
    final d = p.daysUntilExpiry;
    if (d == null) {
      later.add(p);
    } else if (d <= PantryItem.expiringSoonThresholdDays) {
      soon.add(p);
    } else if (d <= 14) {
      week.add(p);
    } else {
      later.add(p);
    }
  }
  return (soon: soon, week: week, later: later);
}
