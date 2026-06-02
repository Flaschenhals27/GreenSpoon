import 'package:shared_preferences/shared_preferences.dart';

/// Speichert die User-Einstellung für Notifications.
/// Nutzt SharedPreferences statt Supabase, weil die Werte auch im
/// Hintergrund-Isolat (ohne aktiven Riverpod-Container) gelesen werden müssen.
class NotificationSettings {
  NotificationSettings._();
  static const _kEnabled = 'notif_enabled';
  static const _kHour = 'notif_hour';
  static const _kMinute = 'notif_minute';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  /// Default: 08:00.
  static Future<({int hour, int minute})> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_kHour) ?? 8,
      minute: prefs.getInt(_kMinute) ?? 0,
    );
  }

  static Future<void> setTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
  }
}
