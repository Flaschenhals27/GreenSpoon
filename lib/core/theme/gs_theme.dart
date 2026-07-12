import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
      // Moderne Seiten-Übergänge statt Default-Zoom: Android bekommt den
      // M3-„Fade forwards"-Übergang, iOS den nativen Slide mit Swipe-Back.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
      // SnackBars im warmen App-Look statt Default-Material: floating,
      // runde Ecken, Ink-Grund mit Cream-Text (invertiert zum Screen).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GSColors.ink,
        contentTextStyle: GoogleFonts.manrope(
          color: GSColors.cream,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: GSColors.honeySoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      // Dialoge (z.B. „Wirklich löschen?") folgen derselben Formsprache
      // wie die Karten: Surface-Ton, 24er-Radius, Newsreader-Titel.
      dialogTheme: DialogThemeData(
        backgroundColor: GSColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
          color: GSColors.ink,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.45,
          color: GSColors.inkSoft,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GSColors.primary,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primary,
          foregroundColor: GSColors.cream,
          disabledBackgroundColor: GSColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: GSColors.cream.withValues(alpha: 0.7),
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
      // Moderne Seiten-Übergänge statt Default-Zoom: Android bekommt den
      // M3-„Fade forwards"-Übergang, iOS den nativen Slide mit Swipe-Back.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
      // SnackBars invertiert zum dunklen Screen: Cream-Grund mit Ink-Text.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GSColors.cream,
        contentTextStyle: GoogleFonts.manrope(
          color: GSColors.ink,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: GSColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GSColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
          color: GSColors.inkDark,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.45,
          color: GSColors.inkSoftDark,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GSColors.primaryMid,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.primaryMid,
          foregroundColor: GSColors.bgAppDark,
          disabledBackgroundColor: GSColors.primaryMid.withValues(alpha: 0.4),
          disabledForegroundColor: GSColors.bgAppDark.withValues(alpha: 0.7),
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
