import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';

/// Farbiger Punkt + Label für Ablauf-Status.
/// Rot ≤ 1 Tag, Orange ≤ 3, Grün ≤ 7, danach gedämpft.
class ExpiryDot extends StatelessWidget {
  const ExpiryDot({super.key, required this.days});
  final int? days;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (days == null) {
      final c = (isDark ? GSColors.paper : GSColors.forest)
          .withValues(alpha: 0.35);
      return _build(c, 'kein MHD');
    }

    final d = days!;
    Color color;
    String label;

    if (d < 0) {
      color = GSColors.expiryUrgent;
      label = 'abgelaufen';
    } else if (d <= 1) {
      color = GSColors.expiryUrgent;
      label = d == 0 ? 'heute' : 'morgen';
    } else if (d <= 3) {
      color = GSColors.expirySoon;
      label = '$d Tage';
    } else if (d <= 7) {
      color = isDark ? GSColors.expiryFreshDark : GSColors.expiryFresh;
      label = '$d Tage';
    } else if (d < 30) {
      color = (isDark ? GSColors.paper : GSColors.forest)
          .withValues(alpha: 0.5);
      label = '$d T.';
    } else {
      color = (isDark ? GSColors.paper : GSColors.forest)
          .withValues(alpha: 0.4);
      label = '${(d / 30).round()} Mon.';
    }

    return _build(color, label);
  }

  Widget _build(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}