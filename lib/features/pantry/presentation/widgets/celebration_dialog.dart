import 'package:flutter/material.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/mascot.dart';

/// Kurzer Feier-Dialog nach dem Verbrauchen — schließt sich nach 1,4 s selbst.
Future<void> showCelebrationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final tone = GSTone.of(ctx);
      // Nur poppen, wenn der Dialog dann noch offen ist (ctx.mounted).
      final nav = Navigator.of(ctx);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (ctx.mounted && nav.canPop()) nav.pop();
      });
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Transform.scale(
          scale: 0.7 + 0.3 * t,
          // easeOutBack überschießt > 1 — für die Opacity klemmen.
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: Dialog(
          backgroundColor: tone.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(pose: MascotPose.celebrating, size: 120),
                const SizedBox(height: 12),
                Text(
                  'Stark, gerettet!',
                  style: GSTypography.headline(color: tone.ink, size: 22),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
