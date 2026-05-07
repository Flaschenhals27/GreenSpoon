import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'gs_colors.dart';

/// Zentrale Theme-Definitionen für Green Spoon.
class GSTheme {
  GSTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: GSColors.primary,
      brightness: Brightness.light,
      primary: GSColors.primary,
      surface: GSColors.cream,
      onSurface: GSColors.forest,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GSColors.cream,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: GSColors.forest,
        displayColor: GSColors.forest,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: GSColors.forest,
      ),
      cardTheme: CardThemeData(
        color: GSColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: GSColors.forest.withValues(alpha: 0.04),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primary,
          foregroundColor: GSColors.paper,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.sand,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: GSColors.primary,
      brightness: Brightness.dark,
      primary: GSColors.primary,
      surface: GSColors.forestDeep,
      onSurface: GSColors.paper,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GSColors.forestDeep,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: GSColors.paper,
        displayColor: GSColors.paper,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.forestDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: GSColors.paper,
      ),
      cardTheme: CardThemeData(
        color: GSColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primary,
          foregroundColor: GSColors.paper,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GSColors.primaryLight, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
