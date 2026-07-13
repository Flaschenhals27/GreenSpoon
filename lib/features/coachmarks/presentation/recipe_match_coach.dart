import 'package:flutter/material.dart';

import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../recipes/presentation/widgets/recipe_chips.dart';
import 'coachmark_scaffold.dart';

/// Erklärt die Match-Prozentzahl auf Rezeptkarten und ihre Farbstufen.
class RecipeMatchCoach extends StatelessWidget {
  const RecipeMatchCoach({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return CoachmarkScaffold(
      eyebrow: 'REZEPTE',
      title: 'Was heißt die Prozentzahl?',
      message: 'Sie zeigt, wie viel von einem Rezept du schon im Vorrat hast — '
          '100 % heißt: alles da, nichts kaufen. Je grüner, desto weniger fehlt.',
      demo: const _MatchDemo(),
      onDismiss: onDismiss,
    );
  }
}

/// Die drei echten Match-Badges nebeneinander, jeweils mit kurzer Erklärung —
/// zeigt die Farbstufen anhand des Original-Widgets.
class _MatchDemo extends StatelessWidget {
  const _MatchDemo();

  static const _samples = [
    (score: 90, caption: 'fast alles da'),
    (score: 60, caption: 'etwas fehlt'),
    (score: 25, caption: 'wenig da'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sample in _samples)
          Expanded(
            child: _MatchSample(score: sample.score, caption: sample.caption),
          ),
      ],
    );
  }
}

class _MatchSample extends StatelessWidget {
  const _MatchSample({required this.score, required this.caption});

  final int score;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MatchBadge(score: score),
        const SizedBox(height: 8),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: GSTypography.body(
            color: tone.inkMute,
            size: 11.5,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
