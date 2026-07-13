import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_typography.dart';

/// Badge mit dem Match-Wert eines Rezepts (wie gut es den Vorrat nutzt).
/// Farbe je nach Score: grün (gut), honey (mittel), terracotta (niedrig).
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    if (score >= 80) {
      color = GSColors.primary;
      bg = GSColors.primary.withValues(alpha: 0.12);
    } else if (score >= 50) {
      color = GSColors.honeyDeep;
      bg = GSColors.honey.withValues(alpha: 0.18);
    } else {
      color = GSColors.accentDeep;
      bg = GSColors.accent.withValues(alpha: 0.14);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      // Zahl zählt beim Erscheinen von 0 auf den Match-Wert hoch.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Text(
          '${value.round()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Kleiner farbiger Tag-Chip (z.B. „Vegetarisch", „Schnell").
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.tint,
    required this.ink,
  });
  final String label;
  final Color tint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            GSTypography.body(color: ink, size: 11.5, weight: FontWeight.w700),
      ),
    );
  }
}

/// Icon + Label für Meta-Infos (Zeit, Schwierigkeit, Portionen).
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
