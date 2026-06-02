import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert die Theme-Wahl des Users in SharedPreferences.
class ThemeSettings {
  ThemeSettings._();
  static const _kKey = 'theme_mode';

  /// Default: System.
  static Future<ThemeMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kKey, raw);
  }
}
