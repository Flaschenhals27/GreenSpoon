import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/scanner/data/co2_estimator.dart';

void main() {
  group('parseWeightKg', () {
    test('Gramm → kg', () {
      expect(Co2Estimator.parseWeightKg('500 g'), 0.5);
      expect(Co2Estimator.parseWeightKg('250g'), 0.25);
    });

    test('Kilogramm', () {
      expect(Co2Estimator.parseWeightKg('1 kg'), 1.0);
      expect(Co2Estimator.parseWeightKg('1,5 kg'), 1.5); // Komma → Punkt
    });

    test('Liter ~ kg', () {
      expect(Co2Estimator.parseWeightKg('0,5 l'), 0.5);
      expect(Co2Estimator.parseWeightKg('1.5 L'), 1.5);
    });

    test('Milliliter → kg', () {
      expect(Co2Estimator.parseWeightKg('250ml'), 0.25);
    });

    test('nicht erkennbare Menge → null', () {
      expect(Co2Estimator.parseWeightKg('6 Stück'), isNull);
      expect(Co2Estimator.parseWeightKg('abc'), isNull);
      expect(Co2Estimator.parseWeightKg(''), isNull);
      expect(Co2Estimator.parseWeightKg(null), isNull);
    });
  });

  group('estimateCo2Kg', () {
    test('Kategorie-Faktor × Gewicht', () {
      // Obst = 0.5 kg CO₂/kg
      expect(
        Co2Estimator.estimateCo2Kg(category: 'Obst', quantity: '1 kg'),
        0.5,
      );
      // Fleisch & Fisch = 15.0, 500 g = 0.5 kg → 7.5
      expect(
        Co2Estimator.estimateCo2Kg(
            category: 'Fleisch & Fisch', quantity: '500 g',),
        7.5,
      );
    });

    test('OFF-Wert übersteuert den Kategorie-Faktor', () {
      expect(
        Co2Estimator.estimateCo2Kg(
            offCo2PerKg: 2.0, category: 'Obst', quantity: '1 kg',),
        2.0,
      );
    });

    test('unbekannte Kategorie → Fallback-Faktor 1.5', () {
      expect(
        Co2Estimator.estimateCo2Kg(category: 'Quatsch', quantity: '1 kg'),
        1.5,
      );
    });

    test('keine Menge → Default-Gewicht 0,5 kg', () {
      // Obst 0.5 × 0.5 = 0.25
      expect(Co2Estimator.estimateCo2Kg(category: 'Obst'), 0.25);
    });
  });

  group('estimatePriceEur', () {
    test('Preis pro kg × Gewicht', () {
      // Fleisch & Fisch = 12 €/kg
      expect(
        Co2Estimator.estimatePriceEur(
            category: 'Fleisch & Fisch', quantity: '1 kg',),
        12.0,
      );
    });

    test('unbekannte Kategorie → Fallback 4 €/kg', () {
      expect(
        Co2Estimator.estimatePriceEur(category: 'Quatsch', quantity: '1 kg'),
        4.0,
      );
    });

    test('keine Menge → Default-Gewicht 0,5 kg', () {
      // Obst 2.5 × 0.5 = 1.25
      expect(Co2Estimator.estimatePriceEur(category: 'Obst'), 1.25);
    });
  });
}
