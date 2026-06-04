import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/notifications/notification_scheduler.dart';
import 'package:green_spoon/features/pantry/domain/pantry_item.dart';

PantryItem _item({required String name, DateTime? expiresAt}) {
  return PantryItem(
    id: name,
    userId: 'u',
    name: name,
    category: 'Sonstiges',
    emoji: '📦',
    createdAt: DateTime(2026, 1, 1),
    expiresAt: expiresAt,
  );
}

void main() {
  group('NotificationScheduler.plan', () {
    // Mittwoch, 04.06.2026, 07:00 — vor der Erinnerungszeit (08:00).
    final now = DateTime(2026, 6, 4, 7, 0);

    test('plant pro Tag mit bald ablaufenden Items genau eine Erinnerung', () {
      final items = [
        _item(name: 'Milch', expiresAt: DateTime(2026, 6, 5)), // morgen
        _item(name: 'Käse', expiresAt: DateTime(2026, 6, 10)), // in 6 Tagen
        _item(name: 'Brot'), // kein MHD → nie
        _item(name: 'Joghurt', expiresAt: DateTime(2026, 6, 1)), // schon ab
      ];

      final plan = NotificationScheduler.plan(
        now: now,
        hour: 8,
        minute: 0,
        items: items,
      );

      // Milch fällt in das 0–2-Tage-Fenster an Slot 0 (heute) & 1 (morgen).
      // Käse fällt in Slot 4, 5, 6 (08.–10.06.). Dazwischen ist nichts.
      expect(plan.map((r) => r.slot).toList(), [0, 1, 4, 5, 6]);
      expect(plan[0].names, ['Milch']);
      expect(plan[0].fireAt, DateTime(2026, 6, 4, 8, 0));
      expect(plan[1].names, ['Milch']);
      expect(plan[2].names, ['Käse']);
      expect(plan[4].fireAt, DateTime(2026, 6, 10, 8, 0));

      // Items ohne MHD oder bereits abgelaufen tauchen nie auf.
      final allNames = plan.expand((r) => r.names).toSet();
      expect(allNames, {'Milch', 'Käse'});
    });

    test('überspringt die heutige Uhrzeit, wenn sie schon vorbei ist', () {
      final afterTime = DateTime(2026, 6, 4, 9, 0); // nach 08:00
      final plan = NotificationScheduler.plan(
        now: afterTime,
        hour: 8,
        minute: 0,
        items: [_item(name: 'Milch', expiresAt: DateTime(2026, 6, 4))],
      );

      // Slot 0 (heute 08:00) liegt in der Vergangenheit → keine Erinnerung.
      expect(plan, isEmpty);
    });

    test('plant nichts, wenn kein Item ein Ablaufdatum hat', () {
      final plan = NotificationScheduler.plan(
        now: now,
        hour: 8,
        minute: 0,
        items: [_item(name: 'Brot'), _item(name: 'Mehl')],
      );

      expect(plan, isEmpty);
    });
  });
}
