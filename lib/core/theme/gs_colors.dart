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

  // ─── Legacy-Aliase (für sanften Übergang) ──────────────────
  // Diese werden im Code noch referenziert. Nach und nach durch neue
  // Tokens ersetzen. Verweisen jetzt auf passende neue Werte.

  /// War: tiefes Tannengrün für Headlines hell. Jetzt: ink.
  static const Color forest = ink;

  /// War: dunkles Waldgrün (App-Hintergrund dark). Jetzt: bgAppDark.
  static const Color forestDeep = bgAppDark;

  /// War: helles Cream. Jetzt: bgApp.
  static const Color cream2 = bgApp;

  /// War: Beige für Akzentflächen. Jetzt: surface2.
  static const Color sand = surface2;

  /// War: Off-White auf dark. Jetzt: inkDark.
  static const Color paper = inkDark;

  /// War: Card-Weiß hell. Jetzt: surface.
  static const Color cardLight = surface;

  /// War: Card dunkel. Jetzt: surfaceDark.
  static const Color cardDark = surfaceDark;

  /// War: Helles Salbeigrün. Jetzt: primaryMid.
  static const Color primaryLight = primaryMid;

  /// Status: läuft ab — gleicher Wert wie accent.
  static const Color expiryUrgent = accent;

  /// Status: läuft bald ab — Honey-Gold.
  static const Color expirySoon = honey;

  /// Status: frisch — primary.
  static const Color expiryFresh = primary;

  /// Status: frisch (Dark) — primaryMid.
  static const Color expiryFreshDark = primaryMid;
}