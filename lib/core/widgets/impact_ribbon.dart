import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';
import '../theme/gs_typography.dart';

/// Grüner Banner mit "Dein Impact"-Anzeige.
/// Zeigt die Verwertungs-Quote (verwertet statt weggeworfen) und CO₂.
class ImpactRibbon extends StatelessWidget {
  const ImpactRibbon({
    super.key,
    this.ratePercent,
    this.co2SavedKg = 0,
    this.onTap,
  });

  /// Verwertungs-Quote in Prozent. `null` = noch keine Bilanz.
  final int? ratePercent;
  final double co2SavedKg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = ratePercent != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: Material(
        color: GSColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, color: GSColors.cream, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: hasData
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$ratePercent %',
                                style: GSTypography.body(
                                  color: GSColors.cream,
                                  size: 15,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: co2SavedKg > 0
                                    ? ' verwertet · ${_formatCo2(co2SavedKg)} CO₂'
                                    : ' verwertet statt weggeworfen',
                                style: GSTypography.body(
                                  color: GSColors.cream.withValues(alpha: 0.85),
                                  size: 13.5,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          'Dein Impact',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GSTypography.body(
                            color: GSColors.cream,
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: GSColors.cream.withValues(alpha: 0.7),
                  size: 18,
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
