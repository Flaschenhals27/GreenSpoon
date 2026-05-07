import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/gs_colors.dart';
import '../../core/theme/gs_typography.dart';
import 'auth/providers/auth_providers.dart';

/// Vorläufiger Home-Screen (wird in Phase 2 durch den echten Vorrat-Screen
/// ersetzt). Dient hier nur, um Login & Logout durchspielen zu können.
class HomeScreenPlaceholder extends ConsumerWidget {
  const HomeScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Mein Vorrat',
                  style: GSTypography.label(color: subtleColor)),
              const SizedBox(height: 6),
              Text(
                'Willkommen 👋',
                style: GSTypography.headline(color: textColor, size: 32),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: GSTypography.body(color: subtleColor, size: 14),
              ),
              const SizedBox(height: 36),

              // Hinweis-Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? GSColors.cardDark : GSColors.cardLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? Colors.white : GSColors.forest)
                        .withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phase 1 läuft 🌱',
                      style: GSTypography.body(
                        color: textColor,
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Auth ist eingerichtet. Als nächstes kommen Vorrat-Tabelle '
                      'in Supabase, Pantry-Screen mit Liste und Filter, sowie '
                      'die ersten Items.',
                      style: GSTypography.body(
                        color: subtleColor,
                        size: 13.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white.withValues(alpha: 0.08)
                              : GSColors.forest.withValues(alpha: 0.06),
                  foregroundColor: textColor,
                ),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                },
                child: const Text('Abmelden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
