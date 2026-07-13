import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/coachmark_store.dart';
import '../domain/coachmark.dart';

/// Persistenz-Abhängigkeit — im Test überschreibbar (z.B. mit einem Fake-Store).
final coachmarkStoreProvider = Provider<CoachmarkStore>(
  (ref) => const SharedPrefsCoachmarkStore(),
);

final coachmarkControllerProvider =
    NotifierProvider<CoachmarkController, CoachmarkState>(
  CoachmarkController.new,
);

/// Hält den Gesehen-Stand der Coachmarks und schreibt jede Änderung über den
/// [CoachmarkStore] zurück.
class CoachmarkController extends Notifier<CoachmarkState> {
  @override
  CoachmarkState build() {
    _load();
    return const CoachmarkState.initial();
  }

  CoachmarkStore get _store => ref.read(coachmarkStoreProvider);

  Future<void> _load() async {
    final seen = await _store.loadSeen();
    state = CoachmarkState(loaded: true, seen: seen);
  }

  /// Merkt sich, dass [mark] gezeigt wurde — im State (sofort sichtbar) und
  /// persistent. Doppelaufrufe sind ein No-op.
  Future<void> markSeen(Coachmark mark) async {
    if (state.seen.contains(mark)) return;
    state = state.withSeen(mark);
    await _store.markSeen(mark);
  }
}
