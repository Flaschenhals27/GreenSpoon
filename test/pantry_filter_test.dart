import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/pantry_filter.dart';
import 'package:green_spoon/features/pantry/domain/pantry_item.dart';

PantryItem _item(
  String name, {
  String category = 'Sonstiges',
  String? brand,
  int? expiresInDays,
}) {
  return PantryItem(
    id: name,
    userId: 'u1',
    name: name,
    category: category,
    emoji: '📦',
    brand: brand,
    expiresAt: expiresInDays == null
        ? null
        : DateTime.now().add(Duration(days: expiresInDays)),
    createdAt: DateTime.now(),
  );
}

void main() {
  group('filterPantryItems', () {
    final items = [
      _item(
        'Milch',
        category: 'Milchprodukte',
        brand: 'Weihenstephan',
        expiresInDays: 1,
      ),
      _item('Tomaten', category: 'Gemüse', expiresInDays: 10),
      _item('Spaghetti', category: 'Pasta & Reis'),
    ];

    test('„Alle" ohne Suche liefert alles', () {
      expect(filterPantryItems(items, filter: kPantryFilterAll), items);
    });

    test('Kategorie-Filter liefert nur diese Kategorie', () {
      final result = filterPantryItems(items, filter: 'Gemüse');
      expect(result.map((p) => p.name), ['Tomaten']);
    });

    test('„Läuft bald ab" nutzt die zentrale 3-Tage-Schwelle', () {
      final result =
          filterPantryItems(items, filter: kPantryFilterExpiringSoon);
      expect(result.map((p) => p.name), ['Milch']);
    });

    test('Suche matcht Name und Marke, case-insensitiv', () {
      expect(
        filterPantryItems(items, filter: kPantryFilterAll, query: 'toma')
            .map((p) => p.name),
        ['Tomaten'],
      );
      expect(
        filterPantryItems(items, filter: kPantryFilterAll, query: 'WEIHEN')
            .map((p) => p.name),
        ['Milch'],
      );
    });

    test('Filter und Suche kombinieren sich', () {
      expect(
        filterPantryItems(items, filter: 'Gemüse', query: 'milch'),
        isEmpty,
      );
    });
  });

  group('groupByFreshness', () {
    test('teilt in bald / zwei Wochen / später, ohne MHD → später', () {
      final groups = groupByFreshness([
        _item('Heute', expiresInDays: 0),
        _item('Bald', expiresInDays: 3),
        _item('Woche', expiresInDays: 10),
        _item('Lang', expiresInDays: 30),
        _item('OhneMhd'),
      ]);
      expect(groups.soon.map((p) => p.name), ['Heute', 'Bald']);
      expect(groups.week.map((p) => p.name), ['Woche']);
      expect(groups.later.map((p) => p.name), ['Lang', 'OhneMhd']);
    });
  });

  group('PantryItem.isExpiringSoon', () {
    test('true bis einschließlich 3 Tage, auch abgelaufen', () {
      expect(_item('a', expiresInDays: -1).isExpiringSoon, isTrue);
      expect(_item('b', expiresInDays: 3).isExpiringSoon, isTrue);
      expect(_item('c', expiresInDays: 4).isExpiringSoon, isFalse);
      expect(_item('d').isExpiringSoon, isFalse);
    });
  });
}
