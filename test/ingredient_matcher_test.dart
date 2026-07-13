import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/pantry_item.dart';
import 'package:green_spoon/features/recipes/domain/ingredient_matcher.dart';

PantryItem _item(String id, String name) => PantryItem(
      id: id,
      userId: 'u1',
      name: name,
      category: 'Sonstiges',
      emoji: '📦',
      createdAt: DateTime.now(),
    );

void main() {
  group('ingredientMatchesItem', () {
    test('matcht beidseitig per contains', () {
      expect(ingredientMatchesItem('Cherry-Tomaten', 'Tomaten'), isTrue);
      expect(ingredientMatchesItem('Milch', 'Bio-Vollmilch'), isTrue);
    });

    test('Groß-/Kleinschreibung und Whitespace sind egal', () {
      expect(ingredientMatchesItem(' paprika ', 'PAPRIKA'), isTrue);
    });

    test('false, wenn nichts passt', () {
      expect(ingredientMatchesItem('Reis', 'Milch'), isFalse);
    });
  });

  group('matchIngredientsToPantry', () {
    test('exakter Namens-Treffer gewinnt vor unscharfem', () {
      final result = matchIngredientsToPantry(
        ['Tomaten'],
        [_item('1', 'Tomatenmark'), _item('2', 'Tomaten')],
      );
      expect(result.matches.single.item.id, '2');
    });

    test('unscharfer Treffer, wenn kein exakter existiert', () {
      final result = matchIngredientsToPantry(
        ['Cherry-Tomaten'],
        [_item('1', 'Tomaten')],
      );
      expect(result.matches.single.item.id, '1');
      expect(result.unmatched, isEmpty);
    });

    test('jedes Item wird höchstens einer Zutat zugeordnet', () {
      final result = matchIngredientsToPantry(
        ['Tomaten', 'Tomaten'],
        [_item('1', 'Tomaten')],
      );
      expect(result.matches, hasLength(1));
      expect(result.unmatched, ['Tomaten']);
    });

    test('sammelt Zutaten ohne Vorrats-Treffer als unmatched', () {
      final result = matchIngredientsToPantry(
        ['Milch', 'Safran'],
        [_item('1', 'Bio-Vollmilch')],
      );
      expect(result.matches.single.ingredient, 'Milch');
      expect(result.unmatched, ['Safran']);
    });

    test('behält die Zutaten-Reihenfolge in den Treffern', () {
      final result = matchIngredientsToPantry(
        ['Eier', 'Milch'],
        [_item('1', 'Milch'), _item('2', 'Eier')],
      );
      expect(
        result.matches.map((m) => m.ingredient).toList(),
        ['Eier', 'Milch'],
      );
    });
  });
}
