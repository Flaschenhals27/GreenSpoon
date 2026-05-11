import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_app_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

import '../../notifications/notification_service.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../../notifications/notification_settings.dart';
import '../../notifications/notification_scheduler.dart';

import 'package:flutter/material.dart' show ThemeMode;
import '../../settings/theme_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifEnabled = false;
  int _notifHour = 8;
  int _notifMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
  }

  Future<void> _loadNotifSettings() async {
    final enabled = await NotificationSettings.isEnabled();
    final t = await NotificationSettings.getTime();
    if (mounted) {
      setState(() {
        _notifEnabled = enabled;
        _notifHour = t.hour;
        _notifMinute = t.minute;
      });
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
              'Bitte erlaube Benachrichtigungen in den Einstellungen.',
            )),
          );
        }
        return;
      }
      await NotificationSettings.setEnabled(true);
      await NotificationScheduler.schedule(
        hour: _notifHour,
        minute: _notifMinute,
      );
      if (mounted) {
        setState(() => _notifEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Tägliche Erinnerung um ${_formatTime(_notifHour, _notifMinute)} aktiviert',
          )),
        );
      }
    } else {
      await NotificationSettings.setEnabled(false);
      await NotificationScheduler.cancel();
      if (mounted) {
        setState(() => _notifEnabled = false);
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      await NotificationSettings.setTime(
        hour: picked.hour,
        minute: picked.minute,
      );
      await NotificationScheduler.schedule(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (mounted) {
        setState(() {
          _notifHour = picked.hour;
          _notifMinute = picked.minute;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(userStatsProvider);

    final email = user?.email ?? 'unbekannt';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final memberSince = user?.createdAt != null
        ? _formatMonthYear(DateTime.parse(user!.createdAt))
        : '—';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            GSAppBar(subtitle: 'Profil', title: email.split('@').first),

            // Avatar + Meta
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [GSColors.primary, GSColors.primaryLight],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: GSTypography.headline(
                        color: GSColors.paper,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: GSTypography.body(
                            color: textColor,
                            size: 14.5,
                            weight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mitglied seit $memberSince',
                          style: GSTypography.body(
                            color: subtleColor,
                            size: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Stats konnten nicht geladen werden.',
                  style: GSTypography.body(color: subtleColor, size: 13),
                ),
              ),
              data: (s) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? GSColors.cardDark : GSColors.cardLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: (isDark ? Colors.white : GSColors.forest)
                          .withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Im Vorrat',
                        value: '${s.inPantry}',
                      ),
                      _Divider(isDark: isDark),
                      _StatRow(
                        label: 'Diese Woche verwertet',
                        value: '${s.cookedThisWeek}',
                      ),
                      _Divider(isDark: isDark),
                      _StatRow(
                        label: 'Insgesamt gerettet',
                        value: '${s.rescued}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // BENACHRICHTIGUNGEN
            // BENACHRICHTIGUNGEN
            // DARSTELLUNG
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'DARSTELLUNG',
                style: GSTypography.label(color: subtleColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? GSColors.cardDark : GSColors.cardLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (isDark ? Colors.white : GSColors.forest)
                        .withValues(alpha: 0.04),
                  ),
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final current =
                        ref.watch(themeModeProvider).value ?? ThemeMode.system;
                    return Column(
                      children: [
                        _ThemeOption(
                          mode: ThemeMode.system,
                          current: current,
                          icon: Icons.brightness_auto,
                          label: 'System',
                          sub: 'Folgt der Geräte-Einstellung',
                          onSelect: (m) =>
                              ref.read(themeModeProvider.notifier).setMode(m),
                          isDark: isDark,
                          textColor: textColor,
                          subtleColor: subtleColor,
                          isFirst: true,
                        ),
                        _ThemeOption(
                          mode: ThemeMode.light,
                          current: current,
                          icon: Icons.light_mode_outlined,
                          label: 'Hell',
                          sub: 'Warmes Beige',
                          onSelect: (m) =>
                              ref.read(themeModeProvider.notifier).setMode(m),
                          isDark: isDark,
                          textColor: textColor,
                          subtleColor: subtleColor,
                        ),
                        _ThemeOption(
                          mode: ThemeMode.dark,
                          current: current,
                          icon: Icons.dark_mode_outlined,
                          label: 'Dunkel',
                          sub: 'Tiefes Tannengrün',
                          onSelect: (m) =>
                              ref.read(themeModeProvider.notifier).setMode(m),
                          isDark: isDark,
                          textColor: textColor,
                          subtleColor: subtleColor,
                          isLast: true,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'BENACHRICHTIGUNGEN',
                style: GSTypography.label(color: subtleColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? GSColors.cardDark : GSColors.cardLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (isDark ? Colors.white : GSColors.forest)
                        .withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    // Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_outlined,
                              color: GSColors.primary, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tägliche Erinnerung',
                                  style: GSTypography.body(
                                    color: textColor,
                                    size: 14.5,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _notifEnabled
                                      ? 'Aktiv um ${_formatTime(_notifHour, _notifMinute)}'
                                      : 'Aus',
                                  style: GSTypography.body(
                                      color: subtleColor, size: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _notifEnabled,
                            activeThumbColor: GSColors.primary,
                            onChanged: _onToggle,
                          ),
                        ],
                      ),
                    ),
                    // Uhrzeit, nur sichtbar wenn aktiviert
                    if (_notifEnabled) ...[
                      Container(
                        height: 1,
                        color: (isDark ? Colors.white : GSColors.forest)
                            .withValues(alpha: 0.04),
                      ),
                      InkWell(
                        onTap: _pickTime,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule,
                                  color: GSColors.primary, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Uhrzeit',
                                  style: GSTypography.body(
                                      color: textColor, size: 14.5),
                                ),
                              ),
                              Text(
                                _formatTime(_notifHour, _notifMinute),
                                style: GSTypography.body(
                                  color: textColor,
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.chevron_right, color: subtleColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Test-Button (nur wenn aktiviert)
                    if (_notifEnabled) ...[
                      Container(
                        height: 1,
                        color: (isDark ? Colors.white : GSColors.forest)
                            .withValues(alpha: 0.04),
                      ),
                      InkWell(
                        onTap: () => _testNotification(context, ref),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_outlined,
                                  color: GSColors.primary, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Test senden',
                                  style: GSTypography.body(
                                      color: textColor, size: 14.5),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: subtleColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'KONTO',
                style: GSTypography.label(color: subtleColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Material(
                color: isDark ? GSColors.cardDark : GSColors.cardLight,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _confirmLogout(context, ref), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.logout,
                            color: GSColors.expiryUrgent, size: 22),
                        const SizedBox(width: 14),
                        Text(
                          'Abmelden',
                          style: GSTypography.body(
                            color: GSColors.expiryUrgent,
                            size: 14.5,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                'Green Spoon · Version 0.508 (Beta)',
                style: GSTypography.italicCaption(color: subtleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime d) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich abmelden?'),
        content: const Text('Du wirst zum Login-Screen zurückgeleitet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _testNotification(BuildContext context, WidgetRef ref) async {
  // Permission anfragen (Android 13+)
  final granted =
      await NotificationService.instance.requestPermission();
  if (!granted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Bitte erlaube Benachrichtigungen in den Einstellungen.',
        )),
      );
    }
    return;
  }

  // Aktuelle ablaufende Items aus Riverpod-Provider holen
  final expiring = ref.read(expiringSoonProvider);

  if (expiring.isEmpty) {
    // Mock-Daten, damit man die Notification trotzdem testen kann
    await NotificationService.instance.showExpiryNotification(
      expiringCount: 2,
      itemNames: ['Skyr Vanille', 'Tomaten'],
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Test-Benachrichtigung gesendet (Beispiel-Daten)',
        )),
      );
    }
  } else {
    await NotificationService.instance.showExpiryNotification(
      expiringCount: expiring.length,
      itemNames: expiring.map((e) => e.name).toList(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          '${expiring.length} ablaufendes Item${expiring.length == 1 ? "" : "s"} → Notification gesendet',
        )),
      );
    }
  }
}
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.current,
    required this.icon,
    required this.label,
    required this.sub,
    required this.onSelect,
    required this.isDark,
    required this.textColor,
    required this.subtleColor,
    this.isFirst = false,
    this.isLast = false,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String label;
  final String sub;
  final ValueChanged<ThemeMode> onSelect;
  final bool isDark;
  final Color textColor;
  final Color subtleColor;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    return Column(
      children: [
        if (!isFirst)
          Container(
            height: 1,
            color: (isDark ? Colors.white : GSColors.forest)
                .withValues(alpha: 0.04),
          ),
        InkWell(
          onTap: () => onSelect(mode),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? GSColors.primary : subtleColor,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GSTypography.body(
                          color: textColor,
                          size: 14.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        sub,
                        style: GSTypography.body(
                            color: subtleColor, size: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: GSColors.primary, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}



class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GSTypography.body(color: textColor, size: 13.5),
            ),
          ),
          Text(
            value,
            style: GSTypography.body(
              color: textColor,
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: (isDark ? Colors.white : GSColors.forest).withValues(alpha: 0.04),
    );
  }
}