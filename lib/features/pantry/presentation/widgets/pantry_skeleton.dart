import 'package:flutter/material.dart';

import '../../../../core/theme/gs_tone.dart';

/// Skeleton-Zustand fürs erste Laden: Platzhalter in der Geometrie echter
/// Rows (48er-Tile, zwei Textzeilen), die sanft pulsieren. Kein Layout-
/// Sprung, wenn die Daten eintreffen — und wirkt schneller als ein Spinner.
class PantrySkeleton extends StatefulWidget {
  const PantrySkeleton({super.key});

  @override
  State<PantrySkeleton> createState() => _PantrySkeletonState();
}

class _PantrySkeletonState extends State<PantrySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final boneColor = tone.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : tone.surface2;

    Widget bone({required double width, required double height, double r = 6}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: boneColor,
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return Semantics(
      label: 'Vorrat wird geladen',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            children: [
              // Header-Platzhalter (Gruß + Headline)
              bone(width: 90, height: 12),
              const SizedBox(height: 16),
              bone(width: 220, height: 30, r: 8),
              const SizedBox(height: 8),
              bone(width: 160, height: 30, r: 8),
              const SizedBox(height: 24),
              // Impact-Ribbon-Platzhalter
              bone(width: double.infinity, height: 42, r: 14),
              const SizedBox(height: 18),
              // Filter-Pills-Platzhalter
              Row(
                children: [
                  for (final w in [64.0, 110.0, 88.0, 72.0]) ...[
                    bone(width: w, height: 34, r: 100),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              // Row-Platzhalter
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: tone.line),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        bone(width: 48, height: 48, r: 12),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bone(width: 140, height: 14, r: 4),
                              const SizedBox(height: 8),
                              bone(width: 90, height: 11, r: 4),
                            ],
                          ),
                        ),
                        bone(width: 56, height: 22, r: 100),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
