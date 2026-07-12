import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pantry/domain/pantry_item.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

/// Logik des einmaligen Erinnerungs-Prompts: fragt, sobald das erste Item
/// mit MHD im Vorrat liegt (persistentes Flag, der Dialog bleibt im Widget).
class ExpiryReminderPrompt {
  static const _promptShownKey = 'notif_prompt_shown';

  /// Session-Guard: höchstens eine Prüfung pro App-Lauf.
  bool _checkedThisSession = false;

  /// True, wenn der Prompt jetzt gezeigt werden soll. Markiert ihn dabei
  /// als gezeigt, damit er nie ein zweites Mal erscheint.
  Future<bool> shouldAsk(List<PantryItem> items) async {
    if (_checkedThisSession) return false;
    if (!items.any((i) => i.expiresAt != null)) return false;
    _checkedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptShownKey) ?? false) return false;
    if (await NotificationSettings.isEnabled()) return false;
    await prefs.setBool(_promptShownKey, true);
    return true;
  }

  /// Fragt die System-Berechtigung an und aktiviert die Erinnerungen.
  /// Liefert false, wenn der User die Berechtigung verweigert hat.
  Future<bool> enable(List<PantryItem> items) async {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) return false;
    await NotificationSettings.setEnabled(true);
    await NotificationScheduler.reschedule(items);
    return true;
  }
}

final expiryReminderPromptProvider =
    Provider<ExpiryReminderPrompt>((ref) => ExpiryReminderPrompt());
