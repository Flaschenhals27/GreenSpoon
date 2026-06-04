import 'package:flutter/foundation.dart';

import '../pantry/domain/pantry_item.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Plant die täglichen Ablauf-Erinnerungen.
///
/// Statt eines WorkManager-Periodic-Tasks (der von Android unzuverlässig und
/// nie zur gewünschten Uhrzeit ausgeführt wurde) planen wir jetzt für die
/// nächsten [horizonDays] Tage je *eine exakte* Notification über den
/// AlarmManager ein. Der Inhalt jedes Tages wird aus dem aktuellen Vorrat
/// berechnet — das geht, weil das Ablaufdatum deterministisch ist: für einen
/// künftigen Stichtag stehen die „bald ablaufenden" Items bereits fest.
///
/// [reschedule] wird aufgerufen, wann immer sich der Vorrat ändert, die App
/// startet oder die Einstellungen angepasst werden. So bleiben die geplanten
/// Erinnerungen aktuell, ohne dass im Hintergrund Daten nachgeladen werden
/// müssten (das frühere, fragile Supabase-Refetch im Hintergrund-Isolat).
class NotificationScheduler {
  NotificationScheduler._();

  /// Wie viele Tage im Voraus geplant wird. Öffnet der User die App innerhalb
  /// dieses Fensters wieder (Normalfall), bleiben die Erinnerungen lückenlos.
  static const horizonDays = 14;

  /// Ein Item gilt an einem Stichtag als „bald ablaufend", wenn es innerhalb
  /// von 0–[_lookaheadDays] Tagen ab diesem Stichtag abläuft.
  static const _lookaheadDays = 2;

  /// Reine, testbare Planungslogik: liefert für jeden Tag mit bald ablaufenden
  /// Items eine Erinnerung (Slot, Auslösezeitpunkt, Item-Namen). Tage ohne
  /// ablaufende Items und die bereits vergangene heutige Uhrzeit werden
  /// ausgelassen.
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
      reminders.add(ScheduledReminder(slot: slot, fireAt: fireAt, names: names));
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
