import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/pantry_categories.dart';

void main() {
  test('Pantry-Kategorien sind eindeutig und enthalten Sonstiges', () {
    expect(kPantryCategories, isNotEmpty);
    expect(
      kPantryCategories.toSet().length,
      kPantryCategories.length,
      reason: 'Kategorien dürfen sich nicht doppeln',
    );
    expect(kPantryCategories, contains('Sonstiges'));
  });
}
