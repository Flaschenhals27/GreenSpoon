import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/recipes/domain/recipe.dart';

Map<String, dynamic> _baseJson({dynamic amounts}) => {
      'title': 'Test',
      'meal': 'Mittag',
      'time_min': 20,
      'difficulty': 'Einfach',
      'servings': 2,
      'tags': <String>[],
      'uses': ['Eier', 'Mehl'],
      'missing': <String>[],
      'blurb': '',
      'steps': <String>[],
      if (amounts != null) 'amounts': amounts,
    };

void main() {
  group('Recipe.amounts', () {
    test('parst Mengen je Zutat', () {
      final r = Recipe.fromJson(
        _baseJson(amounts: {'Eier': '3', 'Mehl': '200 g'}),
      );
      expect(r.amounts['Eier'], '3');
      expect(r.amounts['Mehl'], '200 g');
    });

    test('fehlendes amounts-Feld → leere Map (Alt-Cache)', () {
      final r = Recipe.fromJson(_baseJson());
      expect(r.amounts, isEmpty);
    });

    test('numerische Mengen werden zu String normalisiert', () {
      final r = Recipe.fromJson(_baseJson(amounts: {'Eier': 3}));
      expect(r.amounts['Eier'], '3');
    });

    test('Round-Trip über toJson erhält die Mengen', () {
      final original = Recipe.fromJson(
        _baseJson(amounts: {'Eier': '3'}),
      );
      final restored = Recipe.fromJson(original.toJson());
      expect(restored.amounts, {'Eier': '3'});
    });
  });
}
