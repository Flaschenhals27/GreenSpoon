import 'package:flutter/foundation.dart';

@immutable
class MhdMatch {
  const MhdMatch({required this.date, required this.rawText});
  final DateTime date;
  final String rawText;
}

/// Parsed deutsche MHD-Aufdrucke aus OCR-Rohtext.
///
/// Tolerant gegenüber typischen OCR-Fehlern:
///   - Verwechslungen (l/I/| → 1, O/D → 0, B → 8, Z → 2, S → 5)
///   - Trennzeichen-Varianten (. , : ; - / \ Leerzeichen)
///   - überflüssige Leerzeichen rund um die Ziffern
///
/// Erkannte Formate:
///   12.05.2026   12.05.26   12.5.26
///   2026-05-12   (ISO)
///   12.05        (kurz, nimmt nächstes plausibles Jahr)
class MhdParser {
  MhdParser._();

  /// Wendet OCR-Korrekturen auf den Rohtext an.
  /// Buchstaben, die häufig als Ziffern fehlgelesen werden, werden
  /// nur ersetzt, wenn sie zwischen Ziffern oder Datums-Trennzeichen
  /// stehen — sonst zerstört man echten Text.
  static String _normalizeOcr(String input) {
    var s = input;

    // Verschiedene "punktähnliche" Trenner (Bullet, Mid-Dot, Apostroph)
    // zu echtem Punkt vereinheitlichen.
    s = s.replaceAll(RegExp(r"[·•'`´]"), '.');

    // Whitespace um Trennzeichen weg: "12 . 05 . 2026" → "12.05.2026"
    s = s.replaceAll(RegExp(r'[ \t]*([.,:;\-/\\])[ \t]*'), r'$1');  
    // Lücken zwischen Ziffern, die offensichtlich ein Datum sind, mit Punkt
    // füllen: "29 05 2026" → "29.05.2026"
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

    // Buchstaben → Ziffern, nur in Ziffern-Kontext
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

  static final _patterns = <RegExp>[
    // ISO 2026-05-12 (auch mit Punkt/Slash)
    RegExp(r'\b(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})\b'),
    // 12.05.2026
    RegExp(r'\b(\d{1,2})[.\-/](\d{1,2})[.\-/](20\d{2})\b'),
    // 12.05.26
    RegExp(r'\b(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2})\b'),
    // 12.05 (kurz)
    RegExp(r'\b(\d{1,2})[.\-/](\d{1,2})\b(?!\d)'),
  ];

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
    for (final m in _patterns[0].allMatches(cleaned)) {
      final y = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final d = int.tryParse(m.group(3)!) ?? 0;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 2) dd.mm.yyyy
    for (final m in _patterns[1].allMatches(cleaned)) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final y = int.tryParse(m.group(3)!) ?? 0;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 3) dd.mm.yy
    for (final m in _patterns[2].allMatches(cleaned)) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      final yy = int.tryParse(m.group(3)!) ?? 0;
      final y = yy < 80 ? 2000 + yy : 1900 + yy;
      final date = _safeDate(y, mo, d);
      if (date != null) addIfValid(date, m.group(0)!);
    }

    // 4) dd.mm (kurz)
    // 4) dd.mm (kurz) — nur, wenn KEIN vollständiges Datum mit Jahr im Text
//    gefunden wurde. Sonst gibt's Falschalarme bei Codes wie "L30.08".
    final hasFullDate =
        _patterns[0].hasMatch(cleaned) ||
        _patterns[1].hasMatch(cleaned) ||
        _patterns[2].hasMatch(cleaned);

    if (!hasFullDate) {
      for (final m in _patterns[3].allMatches(cleaned)) {
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
    }

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
}