import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_app_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                'Green Spoon · Version 0.5',
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