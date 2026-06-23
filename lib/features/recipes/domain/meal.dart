/// Tageszeit/Mahlzeit eines Rezepts.
///
/// Die [label]-Strings sind die stabile, persistierte Repräsentation
/// (Supabase-Spalte `saved_recipes.meal`, JSON-Cache) und das, was die Edge
/// Function `generate-recipes` erwartet — deshalb bleiben sie unverändert
/// deutsch. Eine neue Mahlzeit hinzuzufügen heißt: hier einen Enum-Wert
/// ergänzen; switch-Ausdrücke über `Meal` erzwingen dann an allen Stellen
/// die Behandlung (Open/Closed statt verstreuter String-Vergleiche).
///
/// Die Deklarationsreihenfolge bestimmt die Anzeige-Reihenfolge der
/// Rezept-Sektionen.
enum Meal {
  breakfast(label: 'Frühstück', longLabel: 'Frühstück', emoji: '🥐'),
  lunch(label: 'Mittag', longLabel: 'Mittagessen', emoji: '🍽'),
  dinner(label: 'Abend', longLabel: 'Abendessen', emoji: '🍲');

  const Meal({
    required this.label,
    required this.longLabel,
    required this.emoji,
  });

  /// Kurzlabel — zugleich die persistierte/serverseitige Repräsentation.
  final String label;

  /// Ausgeschriebenes Label (z.B. „Mittagessen") für Überschriften.
  final String longLabel;

  /// Leit-Emoji der Mahlzeit.
  final String emoji;

  /// Parst ein persistiertes/serverseitiges [label]. Unbekannte oder fehlende
  /// Werte fallen auf [Meal.lunch] zurück (entspricht dem bisherigen Default
  /// `'Mittag'`).
  static Meal fromLabel(String? value) {
    for (final meal in Meal.values) {
      if (meal.label == value) return meal;
    }
    return Meal.lunch;
  }
}
