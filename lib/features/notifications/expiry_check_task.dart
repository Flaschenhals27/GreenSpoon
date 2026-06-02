import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

/// Eindeutiger Task-Name. WorkManager nutzt das, um Tasks zu identifizieren
/// (also auch zum Canceln).
const expiryCheckTaskName = 'green_spoon_expiry_check';
const expiryCheckUniqueName = 'green_spoon_daily_expiry_check';

/// Wird von WorkManager im Hintergrund-Isolat aufgerufen.
/// MUSS top-level oder static sein und mit @pragma annotiert.
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != expiryCheckTaskName) return true;

    try {
      // .env neu laden — wir sind in einem frischen Isolat
      await dotenv.load(fileName: '.env');

      // Supabase neu initialisieren — die persistierte Session kommt
      // automatisch über flutter_secure_storage zurück
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('[ExpiryCheck] kein User eingeloggt');
        return true;
      }

      // Items, die in 0–2 Tagen ablaufen
      final now = DateTime.now();
      final inTwoDays = DateTime(now.year, now.month, now.day + 2);
      final today = DateTime(now.year, now.month, now.day);

      final response = await client
          .from('pantry_items')
          .select('name, expires_at')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .not('expires_at', 'is', null)
          .gte('expires_at', today.toIso8601String().split('T').first)
          .lte('expires_at', inTwoDays.toIso8601String().split('T').first);

      final items = (response as List).map((r) => r['name'] as String).toList();

      if (items.isNotEmpty) {
        await NotificationService.instance.initialize();
        await NotificationService.instance.showExpiryNotification(
          expiringCount: items.length,
          itemNames: items,
        );
      }

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ExpiryCheck] Fehler: $e');
        debugPrint('$st');
      }
      // false → WorkManager retried; true → Task gilt als erledigt.
      // Wir geben true zurück, damit fehlerhafte Tasks nicht das Gerät spammen.
      return true;
    }
  });
}
