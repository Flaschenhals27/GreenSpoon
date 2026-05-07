import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typografie für Green Spoon.
///
/// - **Fraunces** (Serife): für Headlines, Titles — gibt der App den
///   warmen, etwas redaktionellen Charakter.
/// - **Inter** (Sans): für alle UI-Texte, Listen, Buttons.
class GSTypography {
  GSTypography._();

  /// Headline-Style mit Fraunces.
  static TextStyle headline({
    required Color color,
    double size = 28,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: -0.4,
      color: color,
    );
  }

  /// Body / UI-Text mit Inter.
  static TextStyle body({
    required Color color,
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Kleines Label in Großbuchstaben (für Section-Header).
  static TextStyle label({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.98, // 0.18em bei 11pt
      color: color,
    );
  }

  /// Italic-Footer-Text (z.B. "Green Spoon · Version 1.4").
  static TextStyle italicCaption({required Color color}) {
    return GoogleFonts.fraunces(
      fontSize: 11,
      fontStyle: FontStyle.italic,
      color: color,
    );
  }
}
