import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../main_shell.dart';

/// Kapselt alles rund um lokale Notifications.
///
/// Zwei Wege führen zu einer Notification:
///  * [showExpiryNotification] / [showInfoNotification] — *sofort*, z.B. für den
///    Test-Button im Profil.
///  * [scheduleExpiryReminder] — eine *exakte* Erinnerung zu einem künftigen
///    Zeitpunkt. Das nutzt der [NotificationScheduler], um zuverlässige tägliche
///    Erinnerungen über Androids AlarmManager zu planen (statt des früheren,
///    unzuverlässigen WorkManager-Periodic-Tasks).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'green_spoon_expiry';
  static const _channelName = 'Ablauf-Erinnerungen';
  static const _channelDescription =
      'Benachrichtigungen, wenn Lebensmittel bald ablaufen';

  /// ID der Sofort-Notification (Test-Button).
  static const _immediateId = 0;

  /// Geplante Erinnerungen belegen IDs ab [_scheduledIdBase]. Pro Tag im
  /// Planungshorizont ein Slot, damit wir sie einzeln (re-)setzen und löschen
  /// können, ohne eine evtl. schon sichtbare Sofort-Notification zu treffen.
  static const _scheduledIdBase = 1000;

  /// Wie viele Tagesslots maximal vergeben werden — dient zum sauberen
  /// Aufräumen in [cancelScheduled].
  static const maxScheduledSlots = 31;

  static int scheduledIdForSlot(int slot) => _scheduledIdBase + slot;

  /// Einmal beim App-Start aufrufen.
  Future<void> initialize() async {
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
    // Für punktgenaue tägliche Erinnerungen brauchen wir zusätzlich die
    // Exact-Alarm-Berechtigung (Android 12+). Best effort — schlägt das fehl,
    // fallen wir beim Planen automatisch auf ungenaue Alarme zurück.
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

  /// Plant eine **exakte** Ablauf-Erinnerung für [when] in den Slot [slot].
  /// Nutzt Androids AlarmManager (überlebt App-Schließen & Doze) und fällt auf
  /// ungenaue Alarme zurück, falls Exact-Alarms nicht erlaubt sind.
  Future<void> scheduleExpiryReminder({
    required int slot,
    required DateTime when,
    required List<String> itemNames,
  }) async {
    if (itemNames.isEmpty) return;
    final c = _expiryContent(itemNames);
    // tz.local kann (ohne gesetzte Location) UTC sein — `TZDateTime.from`
    // bewahrt aber den absoluten Zeitpunkt von [when], daher feuert der Alarm
    // zur korrekten Wanduhrzeit.
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

  /// Bittet den User einmalig, die App von der Akkuoptimierung auszunehmen.
  /// Auf aggressiven OEM-ROMs (Xiaomi/MIUI, Samsung, Huawei …) werden sonst
  /// Apps „force-gestoppt", die länger nicht geöffnet wurden — inklusive der
  /// geplanten Alarme. Best effort: zeigt den System-Dialog nur, wenn die
  /// Ausnahme noch nicht erteilt ist, und blockiert nie den Ablauf.
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

  static void _onTapped(NotificationResponse resp) {
    if (resp.payload == 'recipes') {
      // Rezepte-Tab ist Index 1
      mainShellTabNotifier.value = 1;
    }
  }
}
