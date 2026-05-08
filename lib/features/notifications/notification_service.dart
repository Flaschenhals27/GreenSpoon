import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import '../main_shell.dart';

/// Kapselt alles rund um lokale Notifications.
///
/// In Phase 5b.1 nutzen wir die Library, um eine Notification
/// **manuell** vom Profil-Screen aus auszulösen (Test-Button).
/// In Phase 5b.2 kommt der WorkManager dazu, der täglich automatisch
/// `showExpiryNotification` aufruft.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'green_spoon_expiry';
  static const _channelName = 'Ablauf-Erinnerungen';
  static const _channelDescription =
      'Benachrichtigungen, wenn Lebensmittel bald ablaufen';

  /// Einmal beim App-Start aufrufen.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapped,
    );

    // Channel anlegen (nur Android)
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Sofortige Notification — für den Test-Button im Profil.
  Future<void> showExpiryNotification({
    required int expiringCount,
    required List<String> itemNames,
  }) async {
    if (expiringCount == 0) return;

    final preview =
        itemNames.take(3).join(' · ') + (itemNames.length > 3 ? ' …' : '');

    final title = expiringCount == 1
        ? '1 Lebensmittel läuft bald ab'
        : '$expiringCount Lebensmittel laufen bald ab';

    final body = '$preview · Tippe für Rezeptvorschläge';

    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'recipes',
    );
  }

  static void _onTapped(NotificationResponse resp) {
  if (resp.payload == 'recipes') {
    // Rezepte-Tab ist Index 1
    mainShellTabNotifier.value = 1;
  }
}
}