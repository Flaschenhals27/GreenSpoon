import 'package:flutter/material.dart';

/// Farbpalette für Green Spoon — Redesign v2.
/// Warme Naturtöne, tiefes Waldgrün als Akzent, Terracotta als Warnung,
/// Honey-Gold als Sekundär-Akzent.
class GSColors {
  GSColors._();

  // ─── Primärfarben ──────────────────────────────────────────
  /// Tiefes Waldgrün — Hauptakzent für Buttons, aktive Elemente.
  static const Color primary = Color(0xFF2D5A3F);

  /// Dunkleres Waldgrün — für Hover/Pressed-States.
  static const Color primaryDeep = Color(0xFF1F3E2C);

  /// Helles Grünweiß — für Highlights auf primary-Hintergründen.
  static const Color primarySoft = Color(0xFFCFDCD0);

  /// Mittel-Grün — für sekundäre Akzente.
  static const Color primaryMid = Color(0xFF7FA78A);

  // ─── Akzentfarben ──────────────────────────────────────────
  /// Terracotta-Orange — für Warnungen (läuft ab).
  static const Color accent = Color(0xFFD36A3C);

  /// Helles Terracotta — für Warning-Backgrounds.
  static const Color accentSoft = Color(0xFFF3DCC8);

  /// Tiefes Terracotta — für Text auf accentSoft.
  static const Color accentDeep = Color(0xFF8A3C1B);

  /// Honey-Gold — für mittlere Status (z.B. Warn-Gelb).
  static const Color honey = Color(0xFFC89544);

  /// Helles Honey — für Honey-Backgrounds.
  static const Color honeySoft = Color(0xFFF1E2BB);

  /// Tiefes Honey — für Text auf Honey-Backgrounds (z.B. Ablauf-Pille).
  static const Color honeyDeep = Color(0xFF8A6A17);

  /// Gedämpftes Graugrün — neutrale Status-Punkte (z.B. „läuft lange").
  static const Color sage = Color(0xFFA7B1A8);

  /// Warmes Karamell — Illustrationsflächen (z.B. Onboarding).
  static const Color caramel = Color(0xFFC9824E);

  // ─── Hintergründe & Surfaces (Light) ───────────────────────
  /// Haupt-App-Hintergrund: warmes Cream.
  static const Color bgApp = Color(0xFFF5EDE0);

  /// Helles Cream — für hervorgehobene Flächen.
  static const Color cream = Color(0xFFFAF3E3);

  /// Card-Hintergrund — sehr hell.
  static const Color surface = Color(0xFFFBF6EB);

  /// Sekundäre Surface — etwas dunkler, für sub-Karten.
  static const Color surface2 = Color(0xFFEBE1CD);

  /// Subtile Trennlinien (Light).
  static const Color line = Color(0x141A2B22); // rgba(26,43,34,0.08)

  // ─── Text (Light) ──────────────────────────────────────────
  /// Haupttextfarbe.
  static const Color ink = Color(0xFF1A2B22);

  /// Weichere Textfarbe.
  static const Color inkSoft = Color(0xFF4D5E54);

  /// Gedämpfter Text (Hints, Sekundär).
  static const Color inkMute = Color(0xFF8C988E);

  // ─── Dark Mode ─────────────────────────────────────────────
  /// Haupt-App-Hintergrund Dark: tiefes Tannengrün.
  static const Color bgAppDark = Color(0xFF14201A);

  /// Card-Hintergrund Dark.
  static const Color surfaceDark = Color(0xFF1E2A24);

  /// Sekundäre Surface Dark.
  static const Color surface2Dark = Color(0xFF263430);

  /// Trennlinien Dark.
  static const Color lineDark = Color(0x14FAF3E3);

  /// Haupttextfarbe Dark.
  static const Color inkDark = Color(0xFFF5EDE0);

  /// Weichere Textfarbe Dark.
  static const Color inkSoftDark = Color(0xFFB8C2BB);

  /// Gedämpfter Text Dark.
  static const Color inkMuteDark = Color(0xFF7E8B83);
}
