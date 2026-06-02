import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_settings.dart';

/// Hält die aktuelle Theme-Wahl des Users.
/// Lädt initial aus SharedPreferences, persistiert bei jeder Änderung.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    return ThemeSettings.getMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await ThemeSettings.setMode(mode);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
