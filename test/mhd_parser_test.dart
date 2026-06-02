import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/scanner/data/mhd_parser.dart';

void main() {
  // Festes Referenzdatum, damit der Plausibilitätsfilter (Vergangenheit/Zukunft)
  // deterministisch ist — sonst würden die Tests je nach Kalendertag kippen.
  final now = DateTime(2026, 6, 2);

  DateTime? firstDate(String text) {
    final r = MhdParser.parseAll(text, now: now);
    return r.isEmpty ? null : r.first.date;
  }

  group('Vollständige Daten', () {
    test('dd.mm.yyyy', () {
      expect(firstDate('15.11.2026'), DateTime(2026, 11, 15));
    });

    test('ISO yyyy-mm-dd', () {
      expect(firstDate('2026-11-15'), DateTime(2026, 11, 15));
    });

    test('dd.mm.yy (zweistelliges Jahr)', () {
      expect(firstDate('15.11.26'), DateTime(2026, 11, 15));
    });
  });

  group('MM.YYYY (nur Monat + Jahr) → Monatsende', () {
    test('mit Punkt', () {
      expect(firstDate('11.2026'), DateTime(2026, 11, 30));
    });

    test('mit Bindestrich', () {
      expect(firstDate('11-2026'), DateTime(2026, 11, 30));
    });

    test('mit Schrägstrich', () {
      expect(firstDate('11/2026'), DateTime(2026, 11, 30));
    });

    test('Februar → 28 Tage', () {
      expect(firstDate('02.2027'), DateTime(2027, 2, 28));
    });

    test('im Fließtext', () {
      final d = firstDate('Mind. haltbar bis Ende 03.2027');
      expect(d, DateTime(2027, 3, 31));
    });
  });

  group('DD.MM (nur Tag + Monat) → nächstes Vorkommen', () {
    test('Monat noch in der Zukunft → dieses Jahr', () {
      expect(firstDate('30.11'), DateTime(2026, 11, 30));
    });

    test('Monat schon vorbei → nächstes Jahr', () {
      // Referenz ist Juni 2026; Januar ist vorbei → Januar 2027.
      expect(firstDate('15.01'), DateTime(2027, 1, 15));
    });
  });

  group('Robustheit / keine Falschalarme', () {
    test('Chargencode L30.08 ist KEIN Datum', () {
      expect(firstDate('L30.08'), isNull);
    });

    test('Vergangenes Datum wird gefiltert', () {
      expect(firstDate('15.01.2020'), isNull);
    });

    test('Volldatum wird nicht zusätzlich als MM.YYYY doppelt erkannt', () {
      final r = MhdParser.parseAll('15.11.2026', now: now);
      expect(r.length, 1);
      expect(r.first.date, DateTime(2026, 11, 15));
    });

    test('Zwei Daten im Text werden beide erkannt', () {
      final dates = MhdParser.parseAll('15.11.2026 11.2027', now: now)
          .map((m) => m.date)
          .toSet();
      expect(dates, contains(DateTime(2026, 11, 15)));
      expect(dates, contains(DateTime(2027, 11, 30)));
    });
  });

  group('findHint (Teilerkennung für Datepicker-Vorbelegung)', () {
    test('MM.YYYY belegt Monat und Jahr', () {
      final hint = MhdParser.findHint('05.2027');
      expect(hint.month, 5);
      expect(hint.year, 2027);
    });

    test('DD.MM belegt Tag und Monat', () {
      final hint = MhdParser.findHint('12.05');
      expect(hint.day, 12);
      expect(hint.month, 5);
    });
  });
}
