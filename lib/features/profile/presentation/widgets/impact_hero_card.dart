import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../pantry/domain/user_stats.dart';
import '../impact_screen.dart';

/// Großer grüner Impact-Block oben im Profil: Verwertungsquote,
/// Wochen-Zähler und gerettetes CO₂. Tap → [ImpactScreen].
class ImpactHeroCard extends StatelessWidget {
  const ImpactHeroCard({super.key, required this.stats});
  final UserStats stats;

  String _formatCo2(double kg) {
    if (kg >= 10) return kg.toStringAsFixed(0);
    return kg.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Padding(
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
                            color: GSColors.cream.withValues(alpha: 0.6),
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
                            color: GSColors.cream.withValues(alpha: 0.85),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Mascot(pose: MascotPose.celebrating, size: 96),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      label: 'Diese Woche',
                      value: '${s.cookedThisWeek}',
                    ),
                  ),
                  Expanded(
                    child: _HeroStat(
                      label: 'CO₂ gerettet',
                      value: '${_formatCo2(s.co2SavedKg)} kg',
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
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GSTypography.body(
            color: GSColors.cream.withValues(alpha: 0.6),
            size: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GSTypography.headline(
            color: GSColors.cream,
            size: 24,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
