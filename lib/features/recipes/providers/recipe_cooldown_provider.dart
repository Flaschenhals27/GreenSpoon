import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verbleibende Cooldown-Sekunden für den Rezept-Reload.
/// 0 = bereit, > 0 = gesperrt (zählt jede Sekunde runter).
class RecipeCooldownNotifier extends StateNotifier<int> {
  RecipeCooldownNotifier() : super(0);

  Timer? _timer;
  static const _cooldownSeconds = 5;

  /// Startet den Cooldown. Liefert true, wenn der Reload erlaubt war
  /// (also kein laufender Cooldown), sonst false.
  bool trigger() {
    if (state > 0) return false;
    state = _cooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state <= 1) {
        state = 0;
        t.cancel();
      } else {
        state = state - 1;
      }
    });
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final recipeCooldownProvider =
    StateNotifierProvider<RecipeCooldownNotifier, int>(
  (ref) => RecipeCooldownNotifier(),
);