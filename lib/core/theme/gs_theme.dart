import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'gs_colors.dart';

/// Zentrale Theme-Definitionen für Green Spoon (Redesign v2).
class GSTheme {
  GSTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: GSColors.primary,
      brightness: Brightness.light,
      primary: GSColors.primary,
      surface: GSColors.bgApp,
      onSurface: GSColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GSColors.bgApp,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: GSColors.ink,
        displayColor: GSColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.bgApp,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: GSColors.ink,
      ),
      cardTheme: CardThemeData(
        color: GSColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GSColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primary,
          foregroundColor: GSColors.cream,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.manrope(
          color: GSColors.inkMute,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: GSColors.primary,
      brightness: Brightness.dark,
      primary: GSColors.primary,
      surface: GSColors.bgAppDark,
      onSurface: GSColors.inkDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GSColors.bgAppDark,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: GSColors.inkDark,
        displayColor: GSColors.inkDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.bgAppDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: GSColors.inkDark,
      ),
      cardTheme: CardThemeData(
        color: GSColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GSColors.lineDark),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primaryMid,
          foregroundColor: GSColors.bgAppDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.primaryMid, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.manrope(
          color: GSColors.inkMuteDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
