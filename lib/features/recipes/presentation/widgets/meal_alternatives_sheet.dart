import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/meal.dart';
import '../../domain/recipe.dart';
import '../../providers/recipe_providers.dart';
import '../recipe_detail_screen.dart';
import 'recipe_chips.dart';

/// Bottom-Sheet mit 3 frischen Alternativen für eine einzelne Mahlzeit.
/// Wird vom 2-Sekunden-Halten auf einer Rezeptkarte geöffnet.
class MealAlternativesSheet extends ConsumerWidget {
  const MealAlternativesSheet({super.key, required this.meal});
  final Meal meal;

  String get _mealLabel => meal.longLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);
    final async = ref.watch(mealAlternativesProvider(meal));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                child: Row(
                  children: [
                    const Mascot(pose: MascotPose.searching, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FRISCHE IDEEN',
                            style: GSTypography.label(color: tone.inkMute),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Fürs $_mealLabel',
                            style: GSTypography.headline(
                              color: tone.ink,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: tone.inkMute),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => _SheetMessage(
                    pose: MascotPose.searching,
                    title: 'Löffeli kocht sich was aus …',
                    message: 'Drei neue Ideen für dein $_mealLabel.',
                    showSpinner: true,
                  ),
                  error: (e, _) => _SheetMessage(
                    pose: MascotPose.confused,
                    title: 'Hat nicht geklappt',
                    message:
                        'Die Ideen wollten gerade nicht. Versuch es nochmal.',
                    onRetry: () =>
                        ref.invalidate(mealAlternativesProvider(meal)),
                  ),
                  data: (recipes) {
                    if (recipes.isEmpty) {
                      return _SheetMessage(
                        pose: MascotPose.searching,
                        title: 'Nichts gefunden',
                        message:
                            'Aus dem aktuellen Vorrat kam nichts. Nochmal?',
                        onRetry: () =>
                            ref.invalidate(mealAlternativesProvider(meal)),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                      itemCount: recipes.length,
                      itemBuilder: (context, i) {
                        final r = recipes[i];
                        return _AlternativeCard(
                          recipe: r,
                          onChoose: () {
                            ref
                                .read(recipeOverridesProvider.notifier)
                                .set(meal, r);
                            Navigator.of(context).pop();
                          },
                          onDetails: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(recipe: r),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Generischer Lade-/Fehler-Zustand im Auswahl-Sheet.
class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.pose,
    required this.title,
    required this.message,
    this.showSpinner = false,
    this.onRetry,
  });

  final MascotPose pose;
  final String title;
  final String message;
  final bool showSpinner;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Mascot(pose: pose, size: 120),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: tone.ink, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                GSTypography.body(color: tone.inkMute, size: 13, height: 1.45),
          ),
          if (showSpinner) ...[
            const SizedBox(height: 22),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: GSColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(160, 46)),
              child: const Text('Nochmal versuchen'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kompakte Alternativ-Karte im Auswahl-Sheet. Tipp → übernehmen,
/// "Ansehen" → Detail.
class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.recipe,
    required this.onChoose,
    required this.onDetails,
  });

  final Recipe recipe;
  final VoidCallback onChoose;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: tone.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onChoose,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        style: GSTypography.headline(
                          color: tone.ink,
                          size: 19,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    MatchBadge(score: recipe.matchScore),
                  ],
                ),
                if (recipe.blurb.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    recipe.blurb,
                    style: GSTypography.body(
                      color: tone.inkMute,
                      size: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetaChip(
                      icon: Icons.schedule,
                      label: '${recipe.timeMin} Min',
                      color: tone.inkMute,
                    ),
                    const SizedBox(width: 16),
                    MetaChip(
                      icon: Icons.tune,
                      label: recipe.difficulty,
                      color: tone.inkMute,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onDetails,
                      style: TextButton.styleFrom(
                        foregroundColor: GSColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Ansehen'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: GSColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tippen, um zu übernehmen',
                      style: GSTypography.body(
                        color: GSColors.primary,
                        size: 12,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
