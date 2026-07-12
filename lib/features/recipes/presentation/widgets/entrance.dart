import 'package:flutter/material.dart';

/// Wischt ein Kind beim Erscheinen sanft ein (Fade + leichter Slide).
/// [index] staffelt den Start, sodass Karten nacheinander auftauchen.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 55).clamp(0, 600);
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
