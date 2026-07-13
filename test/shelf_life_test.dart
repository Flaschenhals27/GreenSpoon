import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/quantity_utils.dart';
import 'package:green_spoon/features/pantry/domain/shelf_life.dart';

void main() {
  group('ShelfLife.estimateDays', () {
    test('Namens-Treffer schlägt Kategorie', () {
      // „Banane" (5) statt Obst-Default (7)
      expect(
        ShelfLife.estimateDays(name: 'Bananen', category: 'Obst'),
        5,
      );
    });

    test('Kategorie-Default greift ohne Namens-Treffer', () {
      expect(
        ShelfLife.estimateDays(name: 'Drachenfrucht', category: 'Obst'),
        7,
      );
    });

    test('lange haltbar → null (kein Tracking)', () {
      expect(
        ShelfLife.estimateDays(name: 'Spaghetti', category: 'Pasta & Reis'),
        isNull,
      );
      expect(
        ShelfLife.estimateDays(name: 'Salz', category: 'Gewürze & Saucen'),
        isNull,
      );
    });

    test('frisches Fleisch ist knapp bemessen', () {
      expect(
        ShelfLife.estimateDays(
          name: 'Hackfleisch',
          category: 'Fleisch & Fisch',
        ),
        1,
      );
    });

    test('Groß-/Kleinschreibung egal', () {
      expect(
        ShelfLife.estimateDays(name: 'MILCH', category: 'Milchprodukte'),
        7,
      );
    });
  });

  group('ShelfLife.estimateExpiry', () {
    test('heute + geschätzte Tage, auf Tagesgrenze normiert', () {
      final from = DateTime(2026, 7, 12, 15, 30);
      expect(
        ShelfLife.estimateExpiry(name: 'Banane', category: 'Obst', from: from),
        DateTime(2026, 7, 17),
      );
    });

    test('lange haltbar → null', () {
      expect(
        ShelfLife.estimateExpiry(name: 'Reis', category: 'Pasta & Reis'),
        isNull,
      );
    });
  });

  group('scaleQuantity', () {
    test('halbiert Gramm-Angaben', () {
      expect(scaleQuantity('500 g', 0.5), '250 g');
    });

    test('Kilogramm mit Dezimal-Ergebnis → deutsches Komma', () {
      expect(scaleQuantity('1 kg', 0.5), '0,5 kg');
    });

    test('Komma-Eingabe wird verstanden', () {
      expect(scaleQuantity('1,5 l', 0.5), '0,8 l');
    });

    test('Stückzahlen', () {
      expect(scaleQuantity('6 Stück', 0.5), '3 Stück');
    });

    test('ohne Einheit', () {
      expect(scaleQuantity('4', 0.25), '1');
    });

    test('nicht parsebar → null', () {
      expect(scaleQuantity('eine Packung', 0.5), isNull);
      expect(scaleQuantity('', 0.5), isNull);
    });
  });

  group('quantityUnit / isCountableQuantity', () {
    test('Einheit wird erkannt', () {
      expect(quantityUnit('2 Stück'), 'Stück');
      expect(quantityUnit('500 g'), 'g');
      expect(quantityUnit('4'), isNull);
    });

    test('stückzählbar: ganzzahlig + Stück oder ohne Einheit', () {
      expect(isCountableQuantity('2 Stück'), isTrue);
      expect(isCountableQuantity('6 Stk'), isTrue);
      expect(isCountableQuantity('4'), isTrue);
    });

    test('stückzählbar: englische OFF-Einheiten (Eier-Fall)', () {
      expect(isCountableQuantity('10pcs'), isTrue);
      expect(isCountableQuantity('10 pcs'), isTrue);
      expect(isCountableQuantity('6 pieces'), isTrue);
    });

    test('nicht stückzählbar: Gewichte, Volumen, Dezimalzahlen', () {
      expect(isCountableQuantity('500 g'), isFalse);
      expect(isCountableQuantity('1,5 l'), isFalse);
      expect(isCountableQuantity('0,5 Stück'), isFalse);
      expect(isCountableQuantity('eine Packung'), isFalse);
    });
  });

  group('normalizeQuantity', () {
    test('englische Stück-Einheiten → Stück', () {
      expect(normalizeQuantity('10pcs'), '10 Stück');
      expect(normalizeQuantity('6 pieces'), '6 Stück');
      expect(normalizeQuantity('6 stk.'), '6 Stück');
    });

    test('fehlendes Leerzeichen wird ergänzt', () {
      expect(normalizeQuantity('250ml'), '250 ml');
    });

    test('saubere Werte bleiben unverändert', () {
      expect(normalizeQuantity('500 g'), '500 g');
      expect(normalizeQuantity('2 Stück'), '2 Stück');
      expect(normalizeQuantity('eine Packung'), 'eine Packung');
    });
  });

  group('leadingQuantityValue', () {
    test('liest die führende Zahl', () {
      expect(leadingQuantityValue('500 g'), 500);
      expect(leadingQuantityValue('1,5 kg'), 1.5);
      expect(leadingQuantityValue('0,3 Stück'), 0.3);
    });

    test('nicht parsebar → null', () {
      expect(leadingQuantityValue('eine Packung'), isNull);
      expect(leadingQuantityValue(''), isNull);
    });

    test('Rest unter Anzeige-Schwelle erkennbar (0,0-Stück-Bug)', () {
      // 0,1 Stück nochmal geviertelt → 0,025 < 0,05 → das UI verbucht
      // komplett, statt „0,0 Stück" stehen zu lassen.
      final value = leadingQuantityValue('0,1 Stück')!;
      expect(value * 0.25 < 0.05, isTrue);
    });
  });
}
