/// Kontextuelle Erklär-Overlays ("Coachmarks"), die eine Funktion beim ersten
/// Kontakt einmalig erklären. Der [storageKey] merkt sich, dass der User den
/// jeweiligen Hinweis gesehen hat.
enum Coachmark {
  /// Wischen einer Vorrats-Zeile (rechts = verbraucht, links = weggeworfen).
  pantrySwipe('coach_pantry_swipe_seen'),

  /// Bedeutung der Match-Prozentzahl auf einer Rezeptkarte.
  recipeMatch('coach_recipe_match_seen');

  const Coachmark(this.storageKey);

  final String storageKey;
}

/// Welche Coachmarks bereits gesehen wurden — bewusst immutabel, damit die
/// Anzeige-Entscheidung ([shouldShow]) frei von Seiteneffekten und testbar ist.
class CoachmarkState {
  const CoachmarkState({required this.loaded, required this.seen});

  /// Ausgangszustand, solange der persistierte Stand noch nicht geladen ist.
  const CoachmarkState.initial()
      : loaded = false,
        seen = const <Coachmark>{};

  /// True, sobald der gespeicherte Stand vorliegt. Verhindert, dass ein
  /// Coachmark kurz aufblitzt, bevor klar ist, ob er schon gesehen wurde.
  final bool loaded;

  final Set<Coachmark> seen;

  /// Ein Coachmark wird nur gezeigt, wenn der Stand geladen ist und der User
  /// ihn noch nicht gesehen hat.
  bool shouldShow(Coachmark mark) => loaded && !seen.contains(mark);

  CoachmarkState withSeen(Coachmark mark) =>
      CoachmarkState(loaded: loaded, seen: {...seen, mark});
}
