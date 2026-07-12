import '../data/recipe_repository.dart';

/// Anzeige-Texte je Fehlerkategorie — Präsentationsschicht; die
/// erschöpfenden switches erzwingen die Behandlung neuer Typen.
extension RecipeErrorTexts on RecipeErrorType {
  String get emoji => switch (this) {
        RecipeErrorType.offline => '📡',
        RecipeErrorType.geminiDown => '🍳',
        RecipeErrorType.unknown => '🤔',
      };

  String get title => switch (this) {
        RecipeErrorType.offline => 'Keine Verbindung',
        RecipeErrorType.geminiDown => 'Unsere KI macht gerade Pause',
        RecipeErrorType.unknown => 'Da ist was schiefgelaufen',
      };

  String get message => switch (this) {
        RecipeErrorType.offline =>
          'Schau mal, ob WLAN oder Mobilfunk an sind — Rezeptvorschläge brauchen Internet.',
        RecipeErrorType.geminiDown =>
          'Das passiert manchmal kurz. Versuch\'s in einer Minute nochmal.',
        RecipeErrorType.unknown =>
          'Irgendwas hat nicht geklappt. Du kannst es nochmal versuchen — wenn\'s bleibt, schreib uns.',
      };
}
