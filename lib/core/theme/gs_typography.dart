import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typografie für Green Spoon — Redesign v2.
///
/// - **Newsreader** (Serife): für Headlines, Display-Texte — feiner und
///   eleganter als Fraunces, mit variabler Optical-Size-Achse.
/// - **Manrope** (Sans): für UI-Text, Buttons, Labels — geometrischer
///   als Inter, modern aber warm.
class GSTypography {
  GSTypography._();

  /// Headline-Style mit Newsreader.
  /// `size` bestimmt auch die optical size (variable font axis).
  static TextStyle headline({
    required Color color,
    double size = 28,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.newsreader(
      fontSize: size,
      fontWeight: weight,
      height: 1.02,
      letterSpacing: -0.6,
      color: color,
    );
  }

  /// Body / UI-Text mit Manrope.
  static TextStyle body({
    required Color color,
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// "Eyebrow"-Style: kleines Label in Großbuchstaben, weit gespacet.
  /// Für Section-Header wie "VORRAT" oder "BENACHRICHTIGUNGEN".
  static TextStyle label({required Color color}) {
    return GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: color,
    );
  }

  /// Italic-Caption mit Newsreader (Footer-Texte etc.).
  static TextStyle italicCaption({required Color color}) {
    return GoogleFonts.newsreader(
      fontSize: 12,
      fontStyle: FontStyle.italic,
      color: color,
    );
  }
}