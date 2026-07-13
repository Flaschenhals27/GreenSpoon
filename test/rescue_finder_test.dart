import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/pantry_item.dart';
import 'package:green_spoon/features/recipes/domain/rescue_finder.dart';

PantryItem _item(String name) => PantryItem(
      id: name,
      userId: 'u1',
      name: name,
      category: 'Sonstiges',
      emoji: '📦',
      createdAt: DateTime.now(),
    );

void main() {
  group('findRescuedItem', () {
    test('findet Item, dessen Name in einer Zutat steckt', () {
      final result = findRescuedItem(
        [_item('Tomaten')],
        ['Cherry-Tomaten', 'Öl'],
      );
      expect(result?.name, 'Tomaten');
    });

    test('findet Item, wenn die Zutat im Item-Namen steckt', () {
      final result = findRescuedItem(
        [_item('Bio-Vollmilch')],
        ['Milch'],
      );
      expect(result?.name, 'Bio-Vollmilch');
    });

    test('Groß-/Kleinschreibung ist egal', () {
      expect(
        findRescuedItem([_item('PAPRIKA')], ['paprika'])?.name,
        'PAPRIKA',
      );
    });

    test('liefert das erste passende ablaufende Item', () {
      final result = findRescuedItem(
        [_item('Milch'), _item('Eier')],
        ['Eier', 'Milch'],
      );
      expect(result?.name, 'Milch');
    });

    test('null, wenn nichts passt', () {
      expect(findRescuedItem([_item('Milch')], ['Reis']), isNull);
    });
  });
}
