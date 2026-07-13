import 'package:flutter/material.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import 'coachmark_scaffold.dart';

/// Erklärt die Wisch-Gesten im Vorrat: rechts = verbraucht, links = weggeworfen.
class PantrySwipeCoach extends StatelessWidget {
  const PantrySwipeCoach({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return CoachmarkScaffold(
      eyebrow: 'VORRAT',
      title: 'Wischen erledigt alles',
      message: 'Nach rechts wischen, wenn du ein Produkt gegessen hast — nach '
          'links, wenn es in den Müll wandert. Ein Wisch pro Produkt, den Rest '
          'zählen wir für dich.',
      demo: const _SwipeDemo(),
      onDismiss: onDismiss,
    );
  }
}

/// Mock-Vorratszeile, die abwechselnd nach rechts und links wischt und dabei
/// die echten Aktions-Backgrounds enthüllt. Bei reduzierter Bewegung steht
/// die Zeile still und beide Seiten sind gleichzeitig angedeutet.
class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo();

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo>
    with SingleTickerProviderStateMixin {
  static const _maxShift = 58.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  // Wandert 0 → +1 (rechts) → 0 → -1 (links) → 0, mit kurzen Pausen an den
  // Enden, damit die enthüllte Aktion lesbar bleibt.
  late final Animation<double> _shift = _controller.drive(
    TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 5),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(_ease),
        weight: 9,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 6),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(_ease),
        weight: 7,
      ),
      TweenSequenceItem(tween: ConstantTween(0), weight: 5),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0).chain(_ease),
        weight: 9,
      ),
      TweenSequenceItem(tween: ConstantTween(-1), weight: 6),
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 0.0).chain(_ease),
        weight: 7,
      ),
    ]),
  );

  static final _ease = CurveTween(curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 76,
      child: AnimatedBuilder(
        animation: _shift,
        builder: (context, _) {
          final shift = reduceMotion ? 0.0 : _shift.value;
          final rightReveal = reduceMotion ? 0.5 : shift.clamp(0.0, 1.0);
          final leftReveal = reduceMotion ? 0.5 : (-shift).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned.fill(
                child: _ActionPane(
                  color: GSColors.primary,
                  icon: Icons.restaurant,
                  label: 'Verbraucht',
                  alignment: Alignment.centerLeft,
                  opacity: rightReveal,
                ),
              ),
              Positioned.fill(
                child: _ActionPane(
                  color: GSColors.accent,
                  icon: Icons.delete_outline,
                  label: 'Weggeworfen',
                  alignment: Alignment.centerRight,
                  opacity: leftReveal,
                ),
              ),
              Transform.translate(
                offset: Offset(shift * _maxShift, 0),
                child: const _MockRow(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(shift * _maxShift + 34, 6),
                      child: const _HandCursor(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Farbiger Hintergrund, der beim Wischen sichtbar wird — spiegelt die echten
/// Aktions-Backgrounds der Vorratszeile.
class _ActionPane extends StatelessWidget {
  const _ActionPane({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
    required this.opacity,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final leading = alignment == Alignment.centerLeft;
    final row = [
      Icon(icon, color: GSColors.cream, size: 20),
      const SizedBox(width: 8),
      Text(
        label,
        style: GSTypography.body(
          color: GSColors.cream,
          size: 14,
          weight: FontWeight.w700,
        ),
      ),
    ];
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: alignment,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leading ? row : row.reversed.toList(),
        ),
      ),
    );
  }
}

class _MockRow extends StatelessWidget {
  const _MockRow();

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: GSColors.honeySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('🥛', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Milch',
                  style: GSTypography.body(
                    color: tone.ink,
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1,5 % · 1 L',
                  style: GSTypography.body(color: tone.inkMute, size: 12.5),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: GSColors.honey,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Angedeuteter Finger, der mit der Zeile mitwandert.
class _HandCursor extends StatelessWidget {
  const _HandCursor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.touch_app, size: 20, color: GSColors.ink),
    );
  }
}
