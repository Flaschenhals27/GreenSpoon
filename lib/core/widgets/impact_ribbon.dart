import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';
import '../theme/gs_typography.dart';

/// Grüner Banner mit "Dein Impact"-Anzeige.
/// Zeigt gerettete Lebensmittel und optional eingespartes CO₂.
class ImpactRibbon extends StatelessWidget {
  const ImpactRibbon({
    super.key,
    required this.rescuedCount,
    this.co2SavedKg = 0,
    this.onTap,
  });

  final int rescuedCount;
  final double co2SavedKg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Material(
        color: GSColors.primary,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GSColors.cream.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.eco_outlined,
                    color: GSColors.cream,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$rescuedCount',
                            style: GSTypography.headline(
                              color: GSColors.cream,
                              size: 28,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              co2SavedKg > 0
                                  ? 'gerettet · ${_formatCo2(co2SavedKg)} CO₂'
                                  : (rescuedCount == 1
                                      ? 'gerettet'
                                      : 'Lebensmittel gerettet'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GSTypography.body(
                                color: GSColors.cream.withValues(alpha: 0.85),
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: GSColors.cream.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCo2(double kg) {
    if (kg >= 10) return '${kg.toStringAsFixed(0)} kg';
    return '${kg.toStringAsFixed(1)} kg';
  }
}