import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/notification_scheduler.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/notification_settings.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../../recipes/presentation/saved_recipes_screen.dart';
import '../../recipes/providers/saved_recipe_providers.dart';
import '../../settings/theme_providers.dart';
import '../providers/profile_providers.dart';
import 'dietary_prefs_sheet.dart';
import 'impact_screen.dart';
import '../providers/dietary_prefs_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(userStatsProvider);

    final email = user?.email ?? 'unbekannt';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final memberSince = user?.createdAt != null
        ? _formatMonthYear(DateTime.parse(user!.createdAt))
        : '—';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROFIL', style: GSTypography.label(color: muteColor)),
                  const SizedBox(height: 8),
                  Text(
                    email.split('@').first,
                    style: GSTypography.headline(color: inkColor, size: 34),
                  ),
                ],
              ),
            ),

            // Avatar + Meta
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: GSColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: GSTypography.headline(
                        color: GSColors.cream,
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
                            color: inkColor,
                            size: 14.5,
                            weight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mitglied seit $memberSince',
                          style: GSTypography.body(
                            color: muteColor,
                            size: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Großer Impact-Block
            stats.maybeWhen(
              data: (s) => Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImpactScreen()),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: GSColors.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEIN IMPACT',
                                    style: GSTypography.label(
                                      color:
                                          GSColors.cream.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.hasHistory
                                        ? '${(s.useRate * 100).round()} %'
                                        : '—',
                                    style: GSTypography.headline(
                                      color: GSColors.cream,
                                      size: 52,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    s.hasHistory
                                        ? 'verwertet statt weggeworfen'
                                        : 'Verbrauche Items, um deine Quote zu sehen',
                                    style: GSTypography.body(
                                      color: GSColors.cream
                                          .withValues(alpha: 0.85),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Mascot(
                              pose: MascotPose.celebrating,
                              size: 96,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diese Woche',
                                    style: GSTypography.body(
                                      color:
                                          GSColors.cream.withValues(alpha: 0.6),
                                      size: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.cookedThisWeek}',
                                    style: GSTypography.headline(
                                      color: GSColors.cream,
                                      size: 24,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CO₂ gespart',
                                    style: GSTypography.body(
                                      color:
                                          GSColors.cream.withValues(alpha: 0.6),
                                      size: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatCo2(s.co2SavedKg)} kg',
                                    style: GSTypography.headline(
                                      color: GSColors.cream,
                                      size: 24,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Details ansehen',
                              style: GSTypography.body(
                                color: GSColors.cream.withValues(alpha: 0.9),
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: GSColors.cream.withValues(alpha: 0.9),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
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
                  style: GSTypography.body(color: muteColor, size: 13),
                ),
              ),
              data: (s) => _Card(
                isDark: isDark,
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
                    label: 'Verwertet gesamt',
                    value: '${s.consumedTotal}',
                  ),
                  _Divider(isDark: isDark),
                  _StatRow(
                    label: 'Weggeworfen gesamt',
                    value: '${s.wastedTotal}',
                  ),
                  _Divider(isDark: isDark),
                  _StatRow(
                    label: 'Auf den letzten Drücker',
                    value: '${s.buzzerSaves}',
                  ),
                  _Divider(isDark: isDark),
                  _StatRow(
                    label: 'Eingespart (Schätzung)',
                    value: '${s.eurSaved.toStringAsFixed(0)} €',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // MEINE REZEPTE
            _SectionLabel(text: 'MEINE REZEPTE', muteColor: muteColor),
            Consumer(
              builder: (context, ref, _) {
                final saved = ref.watch(savedRecipesProvider);
                final count = saved.maybeWhen(
                  data: (r) => r.length,
                  orElse: () => null,
                );
                final subtitle = count == null
                    ? 'Deine Sammlung'
                    : count == 0
                        ? 'Noch nichts gespeichert'
                        : '$count gespeichert';
                return _Card(
                  isDark: isDark,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SavedRecipesScreen(),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_outline,
                                color: muteColor, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gespeicherte Rezepte',
                                    style: GSTypography.body(
                                      color: inkColor,
                                      size: 14.5,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: GSTypography.body(
                                        color: muteColor, size: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: muteColor, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ERNÄHRUNG
            _SectionLabel(text: 'ERNÄHRUNG', muteColor: muteColor),
            Consumer(
              builder: (context, ref, _) {
                final prefs = ref.watch(dietaryPrefsProvider);
                final tags = prefs.maybeWhen(
                  data: (t) => t,
                  orElse: () => const <String>[],
                );
                return _Card(
                  isDark: isDark,
                  children: [
                    InkWell(
                      onTap: () async {
                        await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DietaryPrefsSheet(initial: tags),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_outlined,
                                color: muteColor, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ernährungsweise',
                                    style: GSTypography.body(
                                      color: inkColor,
                                      size: 14.5,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    tags.isEmpty
                                        ? 'Keine Vorgaben — alles ist ok'
                                        : tags.join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GSTypography.body(
                                        color: muteColor, size: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: muteColor, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // DARSTELLUNG
            _SectionLabel(text: 'DARSTELLUNG', muteColor: muteColor),
            _Card(
              isDark: isDark,
              children: [
                Consumer(
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
                          textColor: inkColor,
                          subtleColor: muteColor,
                          isFirst: true,
                        ),
                        _ThemeOption(
                          mode: ThemeMode.light,
                          current: current,
                          icon: Icons.light_mode_outlined,
                          label: 'Hell',
                          sub: 'Warmes Cream',
                          onSelect: (m) =>
                              ref.read(themeModeProvider.notifier).setMode(m),
                          isDark: isDark,
                          textColor: inkColor,
                          subtleColor: muteColor,
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
                          textColor: inkColor,
                          subtleColor: muteColor,
                          isLast: true,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // BENACHRICHTIGUNGEN
            _SectionLabel(text: 'BENACHRICHTIGUNGEN', muteColor: muteColor),
            _Card(
              isDark: isDark,
              children: [
                // Toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          color:
                              isDark ? GSColors.primaryMid : GSColors.primary,
                          size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tägliche Erinnerung',
                              style: GSTypography.body(
                                color: inkColor,
                                size: 14.5,
                                weight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _notifEnabled
                                  ? 'Aktiv um ${_formatTime(_notifHour, _notifMinute)}'
                                  : 'Aus',
                              style:
                                  GSTypography.body(color: muteColor, size: 12),
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
                if (_notifEnabled) ...[
                  _Divider(isDark: isDark),
                  InkWell(
                    onTap: _pickTime,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              color: isDark
                                  ? GSColors.primaryMid
                                  : GSColors.primary,
                              size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Uhrzeit',
                              style: GSTypography.body(
                                  color: inkColor, size: 14.5),
                            ),
                          ),
                          Text(
                            _formatTime(_notifHour, _notifMinute),
                            style: GSTypography.body(
                              color: inkColor,
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: muteColor),
                        ],
                      ),
                    ),
                  ),
                  _Divider(isDark: isDark),
                  InkWell(
                    onTap: () => _testNotification(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              color: isDark
                                  ? GSColors.primaryMid
                                  : GSColors.primary,
                              size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Test senden',
                              style: GSTypography.body(
                                  color: inkColor, size: 14.5),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: muteColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // KONTO
            _SectionLabel(text: 'KONTO', muteColor: muteColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Material(
                color: isDark ? GSColors.surfaceDark : GSColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _confirmLogout(context, ref),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? GSColors.lineDark : GSColors.line,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.logout,
                            color: GSColors.accent, size: 22),
                        const SizedBox(width: 14),
                        Text(
                          'Abmelden',
                          style: GSTypography.body(
                            color: GSColors.accent,
                            size: 14.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'GreenSpoon · Version 0.508 (Beta)',
                style: GSTypography.italicCaption(color: muteColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime d) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatCo2(double kg) {
    if (kg >= 10) return kg.toStringAsFixed(0);
    return kg.toStringAsFixed(1);
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

  Future<void> _onToggle(bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
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
          SnackBar(
              content: Text(
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

  Future<void> _testNotification(BuildContext context, WidgetRef ref) async {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
            'Bitte erlaube Benachrichtigungen in den Einstellungen.',
          )),
        );
      }
      return;
    }

    final expiring = ref.read(expiringSoonProvider);

    if (expiring.isEmpty) {
      await NotificationService.instance.showExpiryNotification(
        expiringCount: 2,
        itemNames: ['Skyr Vanille', 'Tomaten'],
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
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
          SnackBar(
              content: Text(
            '${expiring.length} ablaufendes Item${expiring.length == 1 ? "" : "s"} → Notification gesendet',
          )),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.muteColor});
  final String text;
  final Color muteColor;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 10),
      child: Text(text, style: GSTypography.label(color: muteColor)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, required this.isDark});
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? GSColors.surfaceDark : GSColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? GSColors.lineDark : GSColors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
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
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GSTypography.body(color: inkColor, size: 14),
            ),
          ),
          Text(
            value,
            style: GSTypography.headline(
              color: inkColor,
              size: 22,
              weight: FontWeight.w500,
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
      color: isDark ? GSColors.lineDark : GSColors.line,
    );
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
    final primaryColor = isDark ? GSColors.primaryMid : GSColors.primary;
    return Column(
      children: [
        if (!isFirst) _Divider(isDark: isDark),
        InkWell(
          onTap: () => onSelect(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? primaryColor : subtleColor,
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
                        style: GSTypography.body(color: subtleColor, size: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: primaryColor, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
