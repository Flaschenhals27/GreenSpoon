/// Schätzt den CO₂-Fußabdruck eines Lebensmittels.
///
/// Strategie:
/// 1. Wenn Open Food Facts einen Wert liefert (kg CO₂ pro kg Produkt),
///    multiplizieren wir mit dem geschätzten Gewicht.
/// 2. Sonst Fallback über eine Kategorie-Map (Werte grob aus
///    Poore & Nemecek 2018, kg CO₂e pro kg Lebensmittel).
class Co2Estimator {
  Co2Estimator._();

  /// Durchschnittliche CO₂e-Werte (kg pro kg Lebensmittel) je Kategorie.
  /// Grobe Schätzwerte — gut genug für eine "Impact"-Anzeige.
  static const _categoryFactors = <String, double>{
    'Milchprodukte': 3.2,
    'Obst': 0.5,
    'Gemüse': 0.4,
    'Fleisch & Fisch': 15.0, // Mischwert; Rind viel höher, Huhn/Fisch niedriger
    'Hülsenfrüchte & Tofu': 2.0, // Linsen/Bohnen/Tofu — pflanzliches Protein
    'Pasta & Reis': 1.6,
    'Brot & Backwaren': 1.1,
    'Backzutaten': 1.1, // Mehl, Zucker, Hefe …
    'Müsli & Cerealien': 1.3,
    'Eier': 4.5,
    'Süßes & Snacks': 3.0,
    'Gewürze & Saucen': 2.0,
    'Öle & Fette': 3.5,
    'Aufstriche': 2.5,
    'Konserven': 1.8,
    'Tiefkühl': 2.5,
    'Getränke': 0.8,
    'Sonstiges': 1.5,
  };

  /// Durchschnittspreis pro kg Lebensmittel je Kategorie (€).
  /// Sehr grobe Schätzung für die "Eingespart"-Anzeige.
  static const _categoryPricePerKg = <String, double>{
    'Milchprodukte': 3.5,
    'Obst': 2.5,
    'Gemüse': 2.5,
    'Fleisch & Fisch': 12.0,
    'Hülsenfrüchte & Tofu': 3.5,
    'Pasta & Reis': 2.0,
    'Brot & Backwaren': 4.0,
    'Backzutaten': 2.0,
    'Müsli & Cerealien': 4.5,
    'Eier': 4.0,
    'Süßes & Snacks': 8.0,
    'Gewürze & Saucen': 6.0,
    'Öle & Fette': 6.0,
    'Aufstriche': 6.0,
    'Konserven': 3.5,
    'Tiefkühl': 5.0,
    'Getränke': 1.5,
    'Sonstiges': 4.0,
  };

  /// Default-Gewicht in kg, wenn die Menge nicht geparst werden kann.
  static const _defaultWeightKg = 0.5;

  /// Versucht, aus einem Mengen-String das Gewicht in kg zu lesen.
  /// Erkennt: "500 g", "0,5 l", "1 kg", "250ml", "1.5 L", "6 Stück" (→ default).
  /// Liefert null, wenn nichts Brauchbares erkennbar.
  static double? parseWeightKg(String? quantity) {
    if (quantity == null || quantity.trim().isEmpty) return null;
    final q = quantity.toLowerCase().replaceAll(',', '.');

    // kg
    final kg = RegExp(r'([\d.]+)\s*kg').firstMatch(q);
    if (kg != null) {
      final v = double.tryParse(kg.group(1)!);
      if (v != null) return v;
    }
    // Liter ~ kg (Wasser-Näherung, reicht für Schätzung)
    final l = RegExp(r'([\d.]+)\s*l\b').firstMatch(q);
    if (l != null) {
      final v = double.tryParse(l.group(1)!);
      if (v != null) return v;
    }
    // Gramm
    final g = RegExp(r'([\d.]+)\s*g\b').firstMatch(q);
    if (g != null) {
      final v = double.tryParse(g.group(1)!);
      if (v != null) return v / 1000.0;
    }
    // Milliliter
    final ml = RegExp(r'([\d.]+)\s*ml').firstMatch(q);
    if (ml != null) {
      final v = double.tryParse(ml.group(1)!);
      if (v != null) return v / 1000.0;
    }
    return null;
  }

  /// Berechnet den CO₂-Wert (kg) für ein Item.
  ///
  /// [offCo2PerKg]: Wert aus Open Food Facts (kg CO₂ pro kg), oder null.
  /// [category]: App-Kategorie für den Fallback-Faktor.
  /// [quantity]: Mengen-String fürs Gewicht.
  static double estimateCo2Kg({
    double? offCo2PerKg,
    required String category,
    String? quantity,
  }) {
    final weightKg = parseWeightKg(quantity) ?? _defaultWeightKg;
    final factor = offCo2PerKg ?? _categoryFactors[category] ?? 1.5;
    return double.parse((factor * weightKg).toStringAsFixed(2));
  }

  /// Schätzt den Geldwert (€) eines Items.
  static double estimatePriceEur({
    required String category,
    String? quantity,
  }) {
    final weightKg = parseWeightKg(quantity) ?? _defaultWeightKg;
    final pricePerKg = _categoryPricePerKg[category] ?? 4.0;
    return double.parse((pricePerKg * weightKg).toStringAsFixed(2));
  }
}
