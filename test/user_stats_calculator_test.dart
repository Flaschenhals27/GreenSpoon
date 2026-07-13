import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/user_stats_calculator.dart';

void main() {
  const calc = UserStatsCalculator();
  // Fester „Jetzt"-Zeitpunkt, damit Wochen-/Monatsgrenzen deterministisch sind.
  final now = DateTime(2026, 6, 23, 12, 0);

  test('leere Daten → nur inPantry gesetzt', () {
    final s = calc.compute(inPantry: 5, consumed: [], wasted: [], now: now);
    expect(s.inPantry, 5);
    expect(s.consumedTotal, 0);
    expect(s.wastedTotal, 0);
    expect(s.co2SavedKg, 0);
    expect(s.eurSaved, 0);
    expect(s.buzzerSaves, 0);
  });

  test('normal verwertet (lange vor MHD): zählt für Woche, spart aber nichts',
      () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [
        ConsumedItem(
          category: 'Obst', // 0.5 kg CO₂/kg, 2,50 €/kg
          quantity: '2 kg',
          expiresAt: DateTime(2026, 6, 30),
          removedAt: DateTime(2026, 6, 20), // < 7 Tage her, 10 Tage vor MHD
        ),
      ],
      wasted: [],
      now: now,
    );
    expect(s.consumedTotal, 1);
    expect(s.cookedThisWeek, 1);
    expect(s.buzzerSaves, 0); // 10 Tage vor MHD verwertet — keine Rettung …
    expect(s.co2SavedKg, 0); // … und damit auch kein vermiedenes CO₂
    expect(s.eurSaved, 0); // … und kein gesparter Ersatzkauf
  });

  test('Rettung (≤ 3 Tage vor MHD): CO₂/€ werden geschätzt und gutgeschrieben',
      () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [
        ConsumedItem(
          category: 'Obst', // 0.5 kg CO₂/kg, 2,50 €/kg
          quantity: '2 kg',
          expiresAt: DateTime(2026, 6, 21),
          removedAt: DateTime(2026, 6, 20), // 1 Tag vor MHD → Rettung
        ),
      ],
      wasted: [],
      now: now,
    );
    expect(s.buzzerSaves, 1);
    expect(s.co2SavedKg, 1.0); // 0.5 × 2
    expect(s.eurSaved, 5.0); // 2.5 × 2
  });

  test('gemessener CO₂-Wert übersteuert die Schätzung (bei Rettung)', () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [
        ConsumedItem(
          category: 'Obst',
          quantity: '2 kg',
          co2Kg: 9.0,
          expiresAt: DateTime(2026, 6, 2),
          removedAt: DateTime(2026, 6, 1), // 1 Tag vor MHD → Rettung
        ),
      ],
      wasted: [],
      now: now,
    );
    expect(s.co2SavedKg, 9.0);
  });

  test('ohne MHD oder Entnahme-Datum: konservativ nie als Rettung werten', () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [
        // Kein MHD → Kontrafaktik „wäre weggeflogen" nicht belegbar.
        ConsumedItem(
          category: 'Obst',
          quantity: '2 kg',
          removedAt: DateTime(2026, 6, 20),
        ),
        // Kein Entnahme-Datum → Restlaufzeit unbestimmbar.
        ConsumedItem(
          category: 'Obst',
          quantity: '2 kg',
          expiresAt: DateTime(2026, 6, 21),
        ),
      ],
      wasted: [],
      now: now,
    );
    expect(s.buzzerSaves, 0);
    expect(s.co2SavedKg, 0);
    expect(s.eurSaved, 0);
  });

  test('nach MHD verwertet: zählt ebenfalls als Rettung', () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [
        ConsumedItem(
          category: 'Sonstiges',
          co2Kg: 2.0,
          expiresAt: DateTime(2026, 5, 30),
          removedAt: DateTime(2026, 6, 1), // 2 Tage NACH MHD gegessen
        ),
      ],
      wasted: [],
      now: now,
    );
    expect(s.buzzerSaves, 1);
    expect(s.co2SavedKg, 2.0);
    expect(s.cookedThisWeek, 0); // länger als 7 Tage her
  });

  test('weggeworfen: Kilo-Bilanz nach Monat, Items ohne Datum ignoriert', () {
    final s = calc.compute(
      inPantry: 0,
      consumed: [],
      wasted: [
        WastedItem(quantity: '1 kg', removedAt: DateTime(2026, 6, 10)),
        WastedItem(quantity: null, removedAt: DateTime(2026, 6, 5)), // 0,5 kg
        WastedItem(quantity: '500 g', removedAt: DateTime(2026, 5, 15)),
        const WastedItem(quantity: '1 kg'), // kein Datum → ignoriert
      ],
      now: now,
    );
    expect(s.wastedTotal, 4);
    expect(s.wastedKgThisMonth, 1.5); // 1.0 + 0.5
    expect(s.wastedKgLastMonth, 0.5);
  });
}
