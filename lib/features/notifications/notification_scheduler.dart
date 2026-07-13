import 'package:flutter/foundation.dart';

import '../pantry/domain/pantry_item.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Plant die täglichen Ablauf-Erinnerungen: je eine exakte Notification pro
/// Tag im [horizonDays]-Fenster, Inhalt deterministisch aus dem Vorrat.
/// [reschedule] läuft bei jeder Vorrats-/Einstellungs-Änderung.
class NotificationScheduler {
  NotificationScheduler._();

  /// Wie viele Tage im Voraus geplant wird. Öffnet der User die App innerhalb
  /// dieses Fensters wieder (Normalfall), bleiben die Erinnerungen lückenlos.
  static const horizonDays = 14;

  /// Ein Item gilt an einem Stichtag als „bald ablaufend", wenn es innerhalb
  /// von 0–[_lookaheadDays] Tagen ab diesem Stichtag abläuft.
  static const _lookaheadDays = 2;

  /// Reine, testbare Planungslogik: eine Erinnerung je Tag mit bald
  /// ablaufenden Items (vergangene heutige Uhrzeit wird ausgelassen).
  @visibleForTesting
  static List<ScheduledReminder> plan({
    required DateTime now,
    required int hour,
    required int minute,
    required List<PantryItem> items,
  }) {
    final reminders = <ScheduledReminder>[];

    for (var slot = 0; slot < horizonDays; slot++) {
      final fireAt =
          DateTime(now.year, now.month, now.day + slot, hour, minute);
      if (!fireAt.isAfter(now)) continue; // heutige Uhrzeit schon vorbei

      final fireDate = DateTime(fireAt.year, fireAt.month, fireAt.day);
      final names = items
          .where((it) {
            final exp = it.expiresAt;
            if (exp == null) return false;
            final daysUntil = DateTime(exp.year, exp.month, exp.day)
                .difference(fireDate)
                .inDays;
            return daysUntil >= 0 && daysUntil <= _lookaheadDays;
          })
          .map((it) => it.name)
          .toList();

      if (names.isEmpty) continue;
      reminders
          .add(ScheduledReminder(slot: slot, fireAt: fireAt, names: names));
    }

    return reminders;
  }

  /// Plant die Erinnerungen für die nächsten Tage neu, basierend auf [items].
  /// Sind Benachrichtigungen deaktiviert, werden alle geplanten gelöscht.
  static Future<void> reschedule(List<PantryItem> items) async {
    await NotificationService.instance.cancelScheduled();

    if (!await NotificationSettings.isEnabled()) return;

    final t = await NotificationSettings.getTime();
    final reminders = plan(
      now: DateTime.now(),
      hour: t.hour,
      minute: t.minute,
      items: items,
    );

    for (final r in reminders) {
      await NotificationService.instance.scheduleExpiryReminder(
        slot: r.slot,
        when: r.fireAt,
        itemNames: r.names,
      );
    }
  }

  /// Löscht alle geplanten Erinnerungen (z.B. beim Ausschalten des Toggles).
  static Future<void> cancel() async {
    await NotificationService.instance.cancelScheduled();
  }
}

/// Eine einzelne geplante Ablauf-Erinnerung (Ergebnis von [NotificationScheduler.plan]).
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.slot,
    required this.fireAt,
    required this.names,
  });

  /// Tagesindex ab heute (0 = heute, 1 = morgen …). Dient als stabile
  /// Notification-ID, damit Re-Planungen denselben Slot überschreiben.
  final int slot;

  /// Wann die Erinnerung ausgelöst werden soll (lokale Wanduhrzeit).
  final DateTime fireAt;

  /// Namen der an diesem Tag bald ablaufenden Items.
  final List<String> names;
}
