import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';

/// Pille mit farbigem Punkt + Label für den Ablauf-Status eines Items.
///
/// Vier Töne abhängig von den Tagen bis Ablauf:
/// - `danger` (Terracotta): heute/morgen oder bereits abgelaufen
/// - `warn` (Honey): 1-2 Tage
/// - `ok` (Waldgrün): 3-7 Tage
/// - `mute` (gedämpft): mehr als 7 Tage
///
/// Heißt aus historischen Gründen noch `ExpiryDot` — der ursprüngliche
/// Name wird im Codebase noch verwendet. Funktional ist's der FreshChip
/// aus dem Redesign.
class ExpiryDot extends StatelessWidget {
  const ExpiryDot({super.key, required this.days});
  final int? days;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (days == null) {
      return _build(
        textColor: isDark ? GSColors.inkMuteDark : GSColors.inkMute,
        bg: Colors.transparent,
        dotColor: isDark ? GSColors.inkMuteDark : GSColors.inkMute,
        label: 'kein MHD',
      );
    }

    final d = days!;
    if (d < 0) {
      return _build(
        textColor: GSColors.accentDeep,
        bg: GSColors.accent.withValues(alpha: 0.14),
        dotColor: GSColors.accent,
        label: 'abgelaufen',
      );
    }
    if (d == 0) {
      return _build(
        textColor: GSColors.accentDeep,
        bg: GSColors.accent.withValues(alpha: 0.14),
        dotColor: GSColors.accent,
        label: 'heute',
      );
    }
    if (d <= 2) {
      return _build(
        textColor: const Color(0xFF8A6A17),
        bg: GSColors.honey.withValues(alpha: 0.18),
        dotColor: GSColors.honey,
        label: '$d ${d == 1 ? "Tag" : "Tage"}',
      );
    }
    if (d <= 7) {
      return _build(
        textColor: isDark ? GSColors.primaryMid : GSColors.primary,
        bg: (isDark ? GSColors.primaryMid : GSColors.primary)
            .withValues(alpha: 0.10),
        dotColor: isDark ? GSColors.primaryMid : GSColors.primary,
        label: '$d Tage',
      );
    }
    if (d < 60) {
      return _build(
        textColor: isDark ? GSColors.inkMuteDark : GSColors.inkMute,
        bg: Colors.transparent,
        dotColor: const Color(0xFFA7B1A8),
        label: '$d T.',
      );
    }
    return _build(
      textColor: isDark ? GSColors.inkMuteDark : GSColors.inkMute,
      bg: Colors.transparent,
      dotColor: const Color(0xFFA7B1A8),
      label: '${(d / 30).round()} Mon.',
    );
  }

  Widget _build({
    required Color textColor,
    required Color bg,
    required Color dotColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
