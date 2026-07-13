import 'pantry_categories.dart';

/// Haltbarkeits-Schätzung für Frischware ohne MHD (Fallback bei Foto-Scan
/// und manueller Eingabe); `null` = lange haltbar → kein Datum-Tracking.
class ShelfLife {
  ShelfLife._();

  /// Namens-Heuristiken (Teilstring, kleingeschrieben) — spezifischer als
  /// die Kategorie. Reihenfolge egal, der erste Treffer gewinnt.
  static const _byName = <String, int>{
    // Sehr kurz
    'beere': 3, 'himbeere': 2, 'erdbeere': 3, 'blaubeere': 5,
    'salat': 4, 'rucola': 3, 'spinat': 4, 'pilz': 4, 'champignon': 4,
    'avocado': 4, 'kirsche': 4, 'feige': 4, 'fisch': 2, 'garnele': 2,
    'hack': 1, 'mett': 1,
    // Kurz
    'banane': 5, 'pfirsich': 5, 'nektarine': 5, 'pflaume': 5,
    'trauben': 5, 'brokkoli': 5, 'blumenkohl': 7, 'zucchini': 7,
    'gurke': 7, 'tomate': 7, 'paprika': 10, 'aubergine': 7,
    'brot': 4, 'brötchen': 2, 'baguette': 2,
    'hähnchen': 2, 'huhn': 2, 'pute': 2, 'wurst': 5, 'schinken': 7,
    // Mittel
    'apfel': 21, 'birne': 10, 'orange': 14, 'mandarine': 10,
    'zitrone': 21, 'limette': 21, 'kiwi': 10, 'mango': 6, 'ananas': 5,
    'möhre': 21, 'karotte': 21, 'kartoffel': 30, 'zwiebel': 30,
    'knoblauch': 60, 'kürbis': 30, 'rote bete': 21, 'kohl': 14,
    'sellerie': 14, 'lauch': 10, 'porree': 10, 'ingwer': 21,
    'milch': 7, 'joghurt': 14, 'quark': 10, 'sahne': 7,
    'frischkäse': 10, 'mozzarella': 7, 'feta': 14, 'butter': 21,
    // Bewusst 'eier', nicht 'ei' — 'ei' träfe auch „Reis"/„Wein"/„Eis".
    'tofu': 7, 'eier': 21,
  };

  /// Kategorie-Defaults, wenn kein Namens-Treffer. `null` = lange haltbar.
  static const _byCategory = <String, int?>{
    'Obst': 7,
    'Gemüse': 7,
    'Milchprodukte': 10,
    'Fleisch & Fisch': 3,
    'Eier': 21,
    'Brot & Backwaren': 4,
    'Hülsenfrüchte & Tofu': null, // getrocknet/Konserve — frisches (Tofu)
    //                               fängt die Namens-Map ab
    'Aufstriche': 30,
    'Tiefkühl': 90,
    // Lange haltbar → kein Tracking:
    'Pasta & Reis': null,
    'Backzutaten': null,
    'Müsli & Cerealien': null,
    'Süßes & Snacks': null,
    'Gewürze & Saucen': null,
    'Konserven': null,
    'Getränke': null,
    kFallbackCategory: null,
  };

  /// Geschätzte Haltbarkeit in Tagen, oder `null` (lange haltbar).
  static int? estimateDays({required String name, required String category}) {
    final n = name.trim().toLowerCase();
    if (n.isNotEmpty) {
      for (final entry in _byName.entries) {
        if (n.contains(entry.key)) return entry.value;
      }
    }
    return _byCategory[category];
  }

  /// Geschätztes Ablaufdatum ab heute, oder `null` (lange haltbar).
  static DateTime? estimateExpiry({
    required String name,
    required String category,
    DateTime? from,
  }) {
    final days = estimateDays(name: name, category: category);
    if (days == null) return null;
    final now = from ?? DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }
}
