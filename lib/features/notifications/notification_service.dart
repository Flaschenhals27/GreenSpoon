import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Kapselt lokale Notifications: Sofort-Anzeigen (Test-Button) und exakte
/// geplante Erinnerungen über Androids AlarmManager.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Tap-Handler (öffnet den Rezepte-Tab) — injiziert, damit der Service
  /// die UI-Schicht nicht kennt (Dependency Inversion).
  VoidCallback? _onOpenRecipes;

  static const _channelId = 'green_spoon_expiry';
  static const _channelName = 'Ablauf-Erinnerungen';
  static const _channelDescription =
      'Benachrichtigungen, wenn Lebensmittel bald ablaufen';

  /// ID der Sofort-Notification (Test-Button).
  static const _immediateId = 0;

  /// Geplante Erinnerungen: ein ID-Slot pro Tag ab [_scheduledIdBase],
  /// getrennt von der Sofort-Notification.
  static const _scheduledIdBase = 1000;

  /// Maximale Tagesslots — Aufräum-Grenze für [cancelScheduled].
  static const maxScheduledSlots = 31;

  static int scheduledIdForSlot(int slot) => _scheduledIdBase + slot;

  /// Einmal beim App-Start aufrufen.
  Future<void> initialize({VoidCallback? onOpenRecipes}) async {
    _onOpenRecipes = onOpenRecipes;
    if (_initialized) return;
    _initialized = true;

    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapped,
    );

    // Channel anlegen (nur Android)
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// Fragt Berechtigung an. Auf Android 13+ ist das nötig, davor egal.
  /// Liefert true, wenn der User zugestimmt hat (oder unter Android 12 läuft).
  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    final granted = await androidImpl.requestNotificationsPermission();
    // Exact-Alarm-Berechtigung (Android 12+) best effort — sonst ungenaue Alarme.
    await androidImpl.requestExactAlarmsPermission();
    return granted ?? true;
  }

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _details = NotificationDetails(android: _androidDetails);

  /// Baut Titel + Text aus den Namen der bald ablaufenden Items.
  static ({String title, String body}) _expiryContent(List<String> itemNames) {
    final count = itemNames.length;
    final preview =
        itemNames.take(3).join(' · ') + (itemNames.length > 3 ? ' …' : '');
    final title = count == 1
        ? '1 Lebensmittel läuft bald ab'
        : '$count Lebensmittel laufen bald ab';
    return (title: title, body: '$preview · Tippe für Rezeptvorschläge');
  }

  /// Sofortige Ablauf-Notification — für den Test-Button im Profil.
  /// Zeigt nur echte Items; bei leerer Liste passiert nichts.
  Future<void> showExpiryNotification({
    required List<String> itemNames,
  }) async {
    if (itemNames.isEmpty) return;
    final c = _expiryContent(itemNames);
    await _plugin.show(
      _immediateId,
      c.title,
      c.body,
      _details,
      payload: 'recipes',
    );
  }

  /// Neutrale Sofort-Notification (z.B. „aktuell läuft nichts ab"),
  /// damit der Test-Button auch dann sichtbar etwas tut.
  Future<void> showInfoNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(_immediateId, title, body, _details);
  }

  /// Plant eine exakte Ablauf-Erinnerung für [when] in Slot [slot]
  /// (Fallback: ungenauer Alarm).
  Future<void> scheduleExpiryReminder({
    required int slot,
    required DateTime when,
    required List<String> itemNames,
  }) async {
    if (itemNames.isEmpty) return;
    final c = _expiryContent(itemNames);
    // TZDateTime.from bewahrt den absoluten Zeitpunkt, auch wenn tz.local UTC ist.
    final scheduled = tz.TZDateTime.from(when, tz.local);
    final id = scheduledIdForSlot(slot);

    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          c.title,
          c.body,
          scheduled,
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'recipes',
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notif] Exakter Alarm fehlgeschlagen ($e) → ungenau.');
      }
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Bittet einmalig um Ausnahme von der Akkuoptimierung — aggressive
  /// OEM-ROMs stoppen sonst auch die geplanten Alarme (best effort).
  Future<void> requestBatteryOptimizationExemption() async {
    try {
      if (await Permission.ignoreBatteryOptimizations.isGranted) return;
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      if (kDebugMode) debugPrint('[Notif] Akku-Ausnahme nicht möglich: $e');
    }
  }

  /// Löscht alle geplanten Erinnerungen (nicht die Sofort-Notification).
  Future<void> cancelScheduled() async {
    for (var slot = 0; slot < maxScheduledSlots; slot++) {
      await _plugin.cancel(scheduledIdForSlot(slot));
    }
  }

  void _onTapped(NotificationResponse resp) {
    if (resp.payload == 'recipes') _onOpenRecipes?.call();
  }
}
