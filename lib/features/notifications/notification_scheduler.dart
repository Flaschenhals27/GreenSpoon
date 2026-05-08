import 'package:workmanager/workmanager.dart';

import 'expiry_check_task.dart';

/// Plant oder stoppt den täglichen Hintergrund-Check.
class NotificationScheduler {
  NotificationScheduler._();

  /// Einmal beim App-Start aufrufen, bevor `schedule` genutzt werden kann.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      workManagerCallbackDispatcher,
      isInDebugMode: false, // bei Bedarf auf true für Debug-Logs
    );
  }

  /// Plant den Task für die nächste Ausführung um (hour:minute) ein
  /// und wiederholt täglich.
  static Future<void> schedule({
    required int hour,
    required int minute,
  }) async {
    // Zuerst evtl. alten Task abbrechen
    await cancel();

    // Wie viele Sekunden bis zur nächsten gewünschten Zeit?
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final initialDelay = next.difference(now);

    await Workmanager().registerPeriodicTask(
      expiryCheckUniqueName,
      expiryCheckTaskName,
      frequency: const Duration(days: 1),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(expiryCheckUniqueName);
  }
}