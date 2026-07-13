import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pantry/domain/pantry_item.dart';
import '../pantry/providers/pantry_providers.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Zustand der täglichen Ablauf-Erinnerung (Toggle + Uhrzeit).
@immutable
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// „08:00"-Format für die Anzeige.
  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

/// Ergebnis eines Test-Versands über [ReminderSettingsController.sendTest].
@immutable
class TestNotificationResult {
  const TestNotificationResult({
    required this.permissionGranted,
    this.expiringCount = 0,
  });

  final bool permissionGranted;

  /// Anzahl der bald ablaufenden Items, auf die sich der Test bezog
  /// (0 → es wurde eine neutrale „alles frisch"-Notification gesendet).
  final int expiringCount;
}

/// ViewModel für die Erinnerungs-Einstellungen im Profil: kapselt
/// Persistenz (SharedPreferences), System-Berechtigung und Neu-Planung —
/// das Widget rendert nur noch Zustand und ruft Aktionen auf.
class ReminderSettingsController extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async {
    final enabled = await NotificationSettings.isEnabled();
    final t = await NotificationSettings.getTime();
    return ReminderSettings(enabled: enabled, hour: t.hour, minute: t.minute);
  }

  List<PantryItem> get _pantryItems =>
      ref.read(pantryStreamProvider).valueOrNull ?? const [];

  ReminderSettings get _current =>
      state.valueOrNull ??
      const ReminderSettings(enabled: false, hour: 8, minute: 0);

  /// Aktiviert die tägliche Erinnerung. Liefert false, wenn der User die
  /// System-Berechtigung verweigert hat (Zustand bleibt dann unverändert).
  Future<bool> enable() async {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) return false;
    await NotificationSettings.setEnabled(true);
    await NotificationScheduler.reschedule(_pantryItems);
    // Für zuverlässige Auslösung auf OEM-ROMs: einmalig um Ausnahme von der
    // Akkuoptimierung bitten (best effort — Erinnerungen laufen auch ohne).
    await NotificationService.instance.requestBatteryOptimizationExemption();
    state = AsyncData(_current.copyWith(enabled: true));
    return true;
  }

  Future<void> disable() async {
    await NotificationSettings.setEnabled(false);
    await NotificationScheduler.cancel();
    state = AsyncData(_current.copyWith(enabled: false));
  }

  Future<void> setTime({required int hour, required int minute}) async {
    await NotificationSettings.setTime(hour: hour, minute: minute);
    await NotificationScheduler.reschedule(_pantryItems);
    state = AsyncData(_current.copyWith(hour: hour, minute: minute));
  }

  /// Sendet eine Test-Notification mit den WIRKLICH bald ablaufenden Items —
  /// frisch aus der DB gelesen, nie aus einem evtl. veralteten Provider und
  /// ohne Beispiel-Daten.
  Future<TestNotificationResult> sendTest() async {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      return const TestNotificationResult(permissionGranted: false);
    }

    final names = <String>[];
    try {
      final expiring =
          await ref.read(pantryRepositoryProvider).fetchExpiringSoon();
      names.addAll(expiring.map((e) => e.name));
    } catch (_) {
      // Netzwerk-/Auth-Fehler behandeln wir wie „nichts läuft bald ab".
    }

    if (names.isEmpty) {
      await NotificationService.instance.showInfoNotification(
        title: 'Alles frisch 🥬',
        body: 'Aktuell läuft in den nächsten Tagen nichts ab.',
      );
    } else {
      await NotificationService.instance
          .showExpiryNotification(itemNames: names);
    }
    return TestNotificationResult(
      permissionGranted: true,
      expiringCount: names.length,
    );
  }
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsController, ReminderSettings>(
  ReminderSettingsController.new,
);
