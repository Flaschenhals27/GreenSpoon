import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';

/// Gemeinsames Gerüst aller Coachmarks: abgedunkelter Hintergrund und eine
/// zentrierte Karte aus Demo-Bereich (die animierte Illustration) und Text.
///
/// Kümmert sich um Ein-/Ausblenden und Wegtippen — die konkreten Coachmarks
/// liefern nur [demo] und die Texte. Beim Schließen läuft erst die Animation
/// rückwärts, danach [onDismiss].
class CoachmarkScaffold extends StatefulWidget {
  const CoachmarkScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.demo,
    required this.onDismiss,
  });

  final String eyebrow;
  final String title;
  final String message;
  final Widget demo;
  final VoidCallback onDismiss;

  @override
  State<CoachmarkScaffold> createState() => _CoachmarkScaffoldState();
}

class _CoachmarkScaffoldState extends State<CoachmarkScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _controller.reverse().whenComplete(widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) {
        final t = _fade.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3 * t, sigmaY: 3 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.62 * t),
                  ),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 24),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: _Card(
        tone: tone,
        eyebrow: widget.eyebrow,
        title: widget.title,
        message: widget.message,
        demo: widget.demo,
        onDismiss: _close,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.demo,
    required this.onDismiss,
  });

  final GSTone tone;
  final String eyebrow;
  final String title;
  final String message;
  final Widget demo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: tone.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: tone.primary
                      .withValues(alpha: tone.isDark ? 0.16 : 0.07),
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
                  child: demo,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow, style: GSTypography.label(color: tone.inkMute)),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: GSTypography.headline(color: tone.ink, size: 26),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: GSTypography.body(
                          color: tone.inkMute,
                          size: 14.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: onDismiss,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          'Verstanden',
                          style: GSTypography.body(
                            color: GSColors.cream,
                            size: 15,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
