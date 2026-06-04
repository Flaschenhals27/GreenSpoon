import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/profile/domain/co2_equivalents.dart';

void main() {
  group('Co2Equivalents.forKg', () {
    test('0 oder negativ → leere Liste', () {
      expect(Co2Equivalents.forKg(0), isEmpty);
      expect(Co2Equivalents.forKg(-5), isEmpty);
    });

    test('liefert die fünf Vergleiche', () {
      final eq = Co2Equivalents.forKg(1.5);
      expect(eq, hasLength(5));
      expect(eq.map((e) => e.label), [
        'Autofahrt',
        'Busfahrt',
        'Handy laden',
        'Warm duschen',
        'Baum-Arbeit',
      ]);
    });

    test('Autofahrt: 1,5 kg / 0,15 = 10 km', () {
      final car = Co2Equivalents.forKg(1.5).first;
      expect(car.emoji, '🚗');
      expect(car.value, '≈ 10 km');
    });
  });

  group('Co2Equivalents.flightShare', () {
    test('Referenzflug (140 kg) = 1.0', () {
      expect(Co2Equivalents.flightShare(140), 1.0);
    });

    test('halber Flug = 0.5', () {
      expect(Co2Equivalents.flightShare(70), 0.5);
    });
  });
}
