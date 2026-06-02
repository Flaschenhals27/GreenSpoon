import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';
import '../theme/gs_typography.dart';

/// Terracotta-Warn-Card oben auf dem Vorrats-Screen,
/// wenn Items in den nächsten 3 Tagen ablaufen.
class ExpiryAlert extends StatelessWidget {
  const ExpiryAlert({
    super.key,
    required this.count,
    required this.preview,
    required this.onTap,
  });

  final int count;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Material(
        color: isDark
            ? GSColors.accent.withValues(alpha: 0.18)
            : GSColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: GSColors.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: GSColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('⏳', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1
                            ? '1 Produkt läuft bald ab'
                            : '$count Produkte laufen bald ab',
                        style: GSTypography.body(
                          color: GSColors.accentDeep,
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GSTypography.body(
                            color: GSColors.accentDeep.withValues(alpha: 0.75),
                            size: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: GSColors.accentDeep.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
