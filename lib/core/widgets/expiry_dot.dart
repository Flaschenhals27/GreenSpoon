import 'package:flutter/material.dart';

import '../theme/gs_colors.dart';
import '../theme/gs_tone.dart';

/// Pille mit Punkt + Label für den Ablauf-Status — Farbe je nach
/// Tagen bis Ablauf (Terracotta/Honey/Grün/gedämpft).
class ExpiryDot extends StatelessWidget {
  const ExpiryDot({super.key, required this.days});
  final int? days;

  /// Screenreader-Text: die visuelle Kurzform („3 T.") ist vorgelesen
  /// kryptisch, deshalb ein ausformulierter Satz.
  String get _semanticLabel {
    final d = days;
    if (d == null) return 'Kein Mindesthaltbarkeitsdatum';
    if (d < 0) return 'Abgelaufen seit ${d.abs()} ${d == -1 ? "Tag" : "Tagen"}';
    if (d == 0) return 'Läuft heute ab';
    if (d == 1) return 'Läuft morgen ab';
    return 'Läuft in $d Tagen ab';
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    if (days == null) {
      return _build(
        textColor: tone.inkMute,
        bg: Colors.transparent,
        dotColor: tone.inkMute,
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
        textColor: tone.primary,
        bg: tone.primary.withValues(alpha: 0.10),
        dotColor: tone.primary,
        label: '$d Tage',
      );
    }
    if (d < 60) {
      return _build(
        textColor: tone.inkMute,
        bg: Colors.transparent,
        dotColor: const Color(0xFFA7B1A8),
        label: '$d T.',
      );
    }
    return _build(
      textColor: tone.inkMute,
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
    return Semantics(
      label: _semanticLabel,
      excludeSemantics: true,
      child: Container(
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
      ),
    );
  }
}
