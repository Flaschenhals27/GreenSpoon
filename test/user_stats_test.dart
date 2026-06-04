import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/data/pantry_repository.dart';

void main() {
  group('UserStats.useRate', () {
    test('Verwertungs-Quote = verwertet / (verwertet + weggeworfen)', () {
      const s = UserStats(consumedTotal: 3, wastedTotal: 1);
      expect(s.useRate, 0.75);
    });

    test('alles verwertet → 1.0', () {
      const s = UserStats(consumedTotal: 4, wastedTotal: 0);
      expect(s.useRate, 1.0);
    });

    test('keine Historie → 0.0 (keine Division durch 0)', () {
      const s = UserStats();
      expect(s.useRate, 0.0);
    });
  });

  group('UserStats.hasHistory', () {
    test('ohne verwertet/weggeworfen → false', () {
      const s = UserStats(inPantry: 5);
      expect(s.hasHistory, isFalse);
    });

    test('sobald etwas den Vorrat verlassen hat → true', () {
      expect(const UserStats(consumedTotal: 1).hasHistory, isTrue);
      expect(const UserStats(wastedTotal: 1).hasHistory, isTrue);
    });
  });
}
