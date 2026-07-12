import '../data/recipe_repository.dart';

/// Nutzerfreundliche Anzeige-Texte je Fehlerkategorie.
///
/// Lebt in der Präsentationsschicht (die Domain kennt keine UI-Texte).
/// Die erschöpfenden switch-Ausdrücke erzwingen, dass ein neuer
/// [RecipeErrorType] hier behandelt werden muss.
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
