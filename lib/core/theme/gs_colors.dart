import 'package:flutter/material.dart';

/// Farbpalette für Green Spoon — abgeleitet aus dem Design-Entwurf
/// (warme Naturtöne, Beige-Hintergrund, Salbeigrün als Akzent).
class GSColors {
  GSColors._();

  // ─── Primärfarben ──────────────────────────────────────────
  /// Salbeigrün — Hauptakzent (Buttons, aktive Tabs).
  static const Color primary = Color(0xFF5C8C56);

  /// Helleres Salbeigrün — für Highlights im Dark Mode.
  static const Color primaryLight = Color(0xFFA8C5A0);

  /// Tiefes Tannengrün — Headlines auf hellem Hintergrund.
  static const Color forest = Color(0xFF1F2A24);

  // ─── Hintergründe (Light) ──────────────────────────────────
  /// Cremiges Beige — App-Hintergrund hell.
  static const Color cream = Color(0xFFF8F4EA);

  /// Wärmeres Beige für Akzentflächen (Chip-Backgrounds, Icon-Tiles).
  static const Color sand = Color(0xFFF4EFE3);

  /// Card-Weiß im Light Mode.
  static const Color cardLight = Color(0xFFFFFFFF);

  // ─── Hintergründe (Dark) ───────────────────────────────────
  /// Dunkles Waldgrün — App-Hintergrund dark.
  static const Color forestDeep = Color(0xFF1A2520);

  /// Card-Hintergrund Dark.
  static const Color cardDark = Color(0xFF26302B);

  /// Off-White für Text auf dunklem Hintergrund.
  static const Color paper = Color(0xFFF0EBE0);

  // ─── Status / Ablauf ───────────────────────────────────────
  /// Rot — läuft heute/morgen ab.
  static const Color expiryUrgent = Color(0xFFC5483A);

  /// Orange — läuft in 2-3 Tagen ab.
  static const Color expirySoon = Color(0xFFD98F3D);

  /// Grün (für Light Mode) — frisch.
  static const Color expiryFresh = Color(0xFF5C8C56);

  /// Helles Grün (für Dark Mode) — frisch.
  static const Color expiryFreshDark = Color(0xFFA8C5A0);
}
