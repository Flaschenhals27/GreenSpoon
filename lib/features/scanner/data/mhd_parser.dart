import 'package:flutter/foundation.dart';

@immutable
class MhdMatch {
  const MhdMatch({required this.date, required this.rawText});
  final DateTime date;
  final String rawText;
}

@immutable
class MhdHint {
  const MhdHint({this.day, this.month, this.year});
  final int? day;
  final int? month;
  final int? year;

  bool get hasAny => day != null || month != null || year != null;
}

class MhdParser {
  MhdParser._();

  /// OCR-Korrekturen: Punkt-Matrix-Verwechslungen, Trenner-Varianten,
  /// nur Inline-Whitespace zusammenziehen (Newlines NIE anfassen!).
  static String _normalizeOcr(String input) {
    var s = input;

    // Punkt-ähnliche Trenner zu echtem Punkt
    s = s.replaceAll(RegExp(r"[·•'`´]"), '.');

    // Inline-Whitespace (Space/Tab) um Trennzeichen entfernen.
    // KEIN \s, das würde Newlines fressen.
    s = s.replaceAllMapped(
      RegExp(r'[ \t]*([.,:;\-/\\])[ \t]*'),
      (m) => m[1]!,
    );

    // Lücken zwischen Ziffern → Punkt (auch hier nur Space/Tab, keine Newlines)
    s = s.replaceAllMapped(
      RegExp(r'\b(\d{1,2})[ \t]+(\d{1,2})[ \t]+(20\d{2})\b'),
      (m) => '${m[1]}.${m[2]}.${m[3]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\b(\d{1,2})[ \t]+(\d{1,2})[ \t]+(\d{2})\b(?!\d)'),
      (m) => '${m[1]}.${m[2]}.${m[3]}',
    );

    // Komma/Doppelpunkt/Strichpunkt/Backslash zwischen Ziffern → Punkt
    s = s.replaceAllMapped(
      RegExp(r'(\d)[,:;\\](\d)'),
      (m) => '${m[1]}.${m[2]}',
    );

    // Buchstaben → Ziffern, nur in Ziffern-/Trenner-Kontext
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)[lI|](?=\d|[.\-/])|(?<=[.\-/])[lI|](?=\d)'),
      (_) => '1',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)O(?=\d|[.\-/])|(?<=[.\-/])O(?=\d)'),
      (_) => '0',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)D(?=\d|[.\-/])|(?<=[.\-/])D(?=\d)'),
      (_) => '0',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)B(?=\d|[.\-/])|(?<=[.\-/])B(?=\d)'),
      (_) => '8',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)Z(?=\d|[.\-/])|(?<=[.\-/])Z(?=\d)'),
      (_) => '2',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)S(?=\d|[.\-/])|(?<=[.\-/])S(?=\d)'),
      (_) => '5',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\d)G(?=\d|[.\-/])|(?<=[.\-/])G(?=\d)'),
      (_) => '6',
    );

    return s;
  }

  static final _patternIso = RegExp(r'(?<![\d])(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})(?![\d])');
  static final _patternFull = RegExp(r'(?<![\d])(\d{1,2})[.\-/](\d{1,2})[.\-/](20\d{2})(?![\d])');
  static final _patternShortYear = RegExp(r'(?<![\d])(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2})(?![\d])');
  static final _patternDayMonth = RegExp(r'(?<![\d])(\d{1,2})[.\-/](\d{1,2})(?![\d.\-/])');

  static List<MhdMatch> parseAll(String text) {
    final cleaned = _normalizeOcr(text);
    final matches = <MhdMatch>[];
    final seenDates = <DateTime>{};

    void addIfValid(DateTime d, String raw) {
      if (!_isPlausible(d)) return;
      if (seenDates.contains(d)) return;
      seenDates.add(d);
      matches.add(MhdMatch(date: d, rawText: raw));
    }

    // 1) ISO yyyy-mm-dd
    for (final m in _patternIso.allMatches(cleaned)) {
      final y = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final d = int.tryParse(m.group(3)!) ?? 0;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 2) dd.mm.yyyy
    for (final m in _patternFull.allMatches(cleaned)) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final y = int.tryParse(m.group(3)!) ?? 0;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 3) dd.mm.yy
    for (final m in _patternShortYear.allMatches(cleaned)) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final yy = int.tryParse(m.group(3)!) ?? 0;
      final y = yy < 80 ? 2000 + yy : 1900 + yy;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 4) dd.mm (kurz) — nur wenn KEIN vollständiges Datum gefunden wurde,
    // sonst gibt's Falschalarme bei Codes wie "L30.08".
    final hasFullDate = _patternIso.hasMatch(cleaned) ||
        _patternFull.hasMatch(cleaned) ||
        _patternShortYear.hasMatch(cleaned);

    /*if (!hasFullDate) {
      for (final m in _patternDayMonth.allMatches(cleaned)) {
        final d = int.tryParse(m.group(1)!) ?? 0;
        final mo = int.tryParse(m.group(2)!) ?? 0;
        final now = DateTime.now();
        var date = _safeDate(now.year, mo, d);
        if (date != null &&
            date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = _safeDate(now.year + 1, mo, d);
        }
        if (date != null) addIfValid(date, m.group(0)!);
      }
    }*/ // --- IGNORE --- (zu viele Fehlalarme)

    final now = DateTime.now();
    matches.sort((a, b) {
      final aSoon = a.date.difference(now).inDays.abs();
      final bSoon = b.date.difference(now).inDays.abs();
      return aSoon.compareTo(bSoon);
    });

    return matches;
  }

  static DateTime? _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    try {
      final result = DateTime(y, m, d);
      if (result.year != y || result.month != m || result.day != d) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static bool _isPlausible(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final maxFuture = DateTime(now.year + 6, now.month, now.day);
    return date.isAfter(yesterday) && date.isBefore(maxFuture);
  }

  /// Sucht im OCR-Text nach Teilerkennungen für die Vorbelegung des
/// Datepickers, falls kein vollständiges Datum erkannt wurde.
/// Liefert Tag und/oder Monat, falls plausibel.
  static MhdHint findHint(String text) {
    final cleaned = _normalizeOcr(text);

    // Tag/Monat ohne Jahr (z.B. "12.05" — aber nur wenn isoliert,
    // nicht als Teil von "L30.08")
    final dm = RegExp(r'(?<![\d\w])(\d{1,2})[.\-/](\d{1,2})(?![\d.\-/])');
    for (final m in dm.allMatches(cleaned)) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12) {
        return MhdHint(day: d, month: mo);
      }
    }

    // Nur ein einzelner ein- oder zweistelliger Wert in einer Zeile —
    // sehr unsicher, deshalb nicht raten. Eher: nichts liefern.
    return const MhdHint();
  }
}