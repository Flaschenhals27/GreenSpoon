import 'package:flutter/material.dart';

import '../theme/gs_tone.dart';
import '../theme/gs_typography.dart';

/// Header im Green-Spoon-Stil: kleines Label oben, große Serifen-Headline,
/// optional ein Widget rechts.
class GSAppBar extends StatelessWidget {
  const GSAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.right,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? right;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final textColor = tone.ink;
    final subtleColor = tone.ink.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.ink.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, size: 18, color: textColor),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!.toUpperCase(),
                    style: GSTypography.label(color: subtleColor),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSTypography.headline(color: textColor, size: 28),
                ),
              ],
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}
