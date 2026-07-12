import 'package:flutter/material.dart';

import 'gs_colors.dart';

/// Helligkeitsabhängige Farbrollen (Single Source of Truth) — Widgets
/// holen sich per [GSTone.of] das passende Set statt eigener isDark-Ternaries.
class GSTone {
  const GSTone._({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkMute,
    required this.primary,
  });

  /// True im Dark-Mode — für seltene Sonderfälle (z.B. Alpha-Anpassungen),
  /// die sich nicht über eine Farbrolle abbilden lassen.
  final bool isDark;

  /// App-Hintergrund (Screens, Sheets).
  final Color bg;

  /// Karten-/Flächenfarbe.
  final Color surface;

  /// Sekundäre, leicht abgesetzte Fläche (Sub-Karten).
  final Color surface2;

  /// Subtile Trennlinien und Rahmen.
  final Color line;

  /// Haupttextfarbe.
  final Color ink;

  /// Weichere Textfarbe.
  final Color inkSoft;

  /// Gedämpfter Text (Hints, Sekundär).
  final Color inkMute;

  /// Primär-Akzent mit ausreichend Kontrast zum jeweiligen Hintergrund.
  final Color primary;

  static const GSTone light = GSTone._(
    isDark: false,
    bg: GSColors.bgApp,
    surface: GSColors.surface,
    surface2: GSColors.surface2,
    line: GSColors.line,
    ink: GSColors.ink,
    inkSoft: GSColors.inkSoft,
    inkMute: GSColors.inkMute,
    primary: GSColors.primary,
  );

  static const GSTone dark = GSTone._(
    isDark: true,
    bg: GSColors.bgAppDark,
    surface: GSColors.surfaceDark,
    surface2: GSColors.surface2Dark,
    line: GSColors.lineDark,
    ink: GSColors.inkDark,
    inkSoft: GSColors.inkSoftDark,
    inkMute: GSColors.inkMuteDark,
    primary: GSColors.primaryMid,
  );

  /// Liefert das zur aktuellen Theme-Helligkeit passende Farbset.
  static GSTone of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
