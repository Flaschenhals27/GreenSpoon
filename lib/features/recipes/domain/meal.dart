/// Tageszeit/Mahlzeit eines Rezepts. Die [label]-Strings sind persistiert
/// (DB, Cache, Edge Function) — nicht ändern. Deklarationsreihenfolge =
/// Anzeige-Reihenfolge der Sektionen.
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

  /// Parst ein persistiertes [label]; unbekannte Werte → [Meal.lunch].
  static Meal fromLabel(String? value) {
    for (final meal in Meal.values) {
      if (meal.label == value) return meal;
    }
    return Meal.lunch;
  }
}
