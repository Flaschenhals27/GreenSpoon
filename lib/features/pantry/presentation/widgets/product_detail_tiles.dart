import 'package:flutter/material.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';

/// Zeile der Details-Liste: Label links, Wert rechts.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GSTypography.body(color: tone.inkMute, size: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GSTypography.body(
                color: tone.ink,
                size: 14,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Haarlinie zwischen zwei [DetailRow]s.
class DetailDivider extends StatelessWidget {
  const DetailDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: GSTone.of(context).line);
}

/// Runder Icon-Button (Zurück, Löschen) mit Tooltip als Screenreader-Label.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final button = Material(
      color: tone.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tone.line),
          ),
          child: Icon(icon, color: color ?? tone.ink, size: 22),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
