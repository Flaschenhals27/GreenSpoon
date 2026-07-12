import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../notifications/reminder_settings_controller.dart';
import 'settings_tiles.dart';

/// „Benachrichtigungen"-Karte: Toggle, Uhrzeit und Test-Versand für die
/// tägliche Ablauf-Erinnerung. Die Logik lebt im
/// [ReminderSettingsController] — hier nur Darstellung und Snackbars.
class ReminderSettingsCard extends ConsumerWidget {
  const ReminderSettingsCard({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
    ReminderSettings settings,
  ) async {
    final controller = ref.read(reminderSettingsProvider.notifier);
    if (!value) {
      await controller.disable();
      return;
    }
    final granted = await controller.enable();
    if (!context.mounted) return;
    _showSnack(
      context,
      granted
          ? 'Tägliche Erinnerung um ${settings.timeLabel} aktiviert'
          : 'Bitte erlaube Benachrichtigungen in den Einstellungen.',
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      await ref
          .read(reminderSettingsProvider.notifier)
          .setTime(hour: picked.hour, minute: picked.minute);
    }
  }

  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(reminderSettingsProvider.notifier).sendTest();
    if (!context.mounted) return;
    if (!result.permissionGranted) {
      _showSnack(
        context,
        'Bitte erlaube Benachrichtigungen in den Einstellungen.',
      );
    } else if (result.expiringCount == 0) {
      _showSnack(context, 'Test gesendet — aktuell läuft nichts bald ab.');
    } else {
      final n = result.expiringCount;
      _showSnack(
        context,
        '$n ablaufendes Item${n == 1 ? "" : "s"} → Test gesendet.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);
    final settings = ref.watch(reminderSettingsProvider).valueOrNull ??
        const ReminderSettings(enabled: false, hour: 8, minute: 0);

    return SettingsCard(
      children: [
        // Toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: tone.primary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tägliche Erinnerung',
                      style: GSTypography.body(
                        color: tone.ink,
                        size: 14.5,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      settings.enabled
                          ? 'Aktiv um ${settings.timeLabel}'
                          : 'Aus',
                      style: GSTypography.body(color: tone.inkMute, size: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.enabled,
                activeThumbColor: GSColors.primary,
                onChanged: (v) => _toggle(context, ref, v, settings),
              ),
            ],
          ),
        ),
        if (settings.enabled) ...[
          const SettingsDivider(),
          InkWell(
            onTap: () => _pickTime(context, ref, settings),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: tone.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Uhrzeit',
                      style: GSTypography.body(color: tone.ink, size: 14.5),
                    ),
                  ),
                  Text(
                    settings.timeLabel,
                    style: GSTypography.body(
                      color: tone.ink,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tone.inkMute),
                ],
              ),
            ),
          ),
          const SettingsDivider(),
          InkWell(
            onTap: () => _sendTest(context, ref),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: tone.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Test senden',
                      style: GSTypography.body(color: tone.ink, size: 14.5),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tone.inkMute),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
