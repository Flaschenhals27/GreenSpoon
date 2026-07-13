import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../domain/recipe.dart';
import 'save_recipe_button.dart';
import 'widgets/cooked_sheet.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final Recipe recipe;

  /// Öffnet das „Gekocht"-Sheet: matcht die Rezept-Zutaten gegen den
  /// Vorrat und verbucht die Auswahl als verbraucht.
  Future<void> _openCookedSheet(BuildContext context) async {
    final consumedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CookedSheet(recipe: recipe),
    );
    if (consumedCount != null && consumedCount > 0 && context.mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

    return Scaffold(
      backgroundColor: tone.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // Top-Bar mit Back + Speichern
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: surfaceColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: lineColor),
                        ),
                        child:
                            Icon(Icons.chevron_left, color: inkColor, size: 22),
                      ),
                    ),
                  ),
                  SaveRecipeButton(recipe: recipe),
                ],
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.meal.label.toUpperCase(),
                    style: GSTypography.label(color: muteColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.title,
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                  if (recipe.blurb.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      recipe.blurb,
                      style: GSTypography.body(
                        color: muteColor,
                        size: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Meta-Zeile
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Row(
                children: [
                  _Meta(
                    icon: Icons.schedule,
                    label: '${recipe.timeMin} Min',
                    color: inkColor,
                    sub: muteColor,
                  ),
                  const SizedBox(width: 24),
                  _Meta(
                    icon: Icons.tune,
                    label: recipe.difficulty,
                    color: inkColor,
                    sub: muteColor,
                  ),
                  const SizedBox(width: 24),
                  _Meta(
                    icon: Icons.people_outline,
                    label: '${recipe.servings} Pers.',
                    color: inkColor,
                    sub: muteColor,
                  ),
                ],
              ),
            ),
            // Tags
            if (recipe.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final t in recipe.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: GSColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: tone.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Zutaten aus dem Vorrat
            if (recipe.uses.isNotEmpty)
              _IngredientBlock(
                title: 'Aus deinem Vorrat',
                items: recipe.uses,
                amounts: recipe.amounts,
                bullet: '✓',
                bulletColor: GSColors.primary,
              ),
            // Zutaten, die fehlen
            if (recipe.missing.isNotEmpty)
              _IngredientBlock(
                title: 'Du brauchst noch',
                items: recipe.missing,
                amounts: recipe.amounts,
                bullet: '+',
                bulletColor: GSColors.accent,
              ),
            // Schritte
            if (recipe.steps.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Text(
                  'ZUBEREITUNG',
                  style: GSTypography.label(color: muteColor),
                ),
              ),
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: GSColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: tone.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            recipe.steps[i],
                            style: GSTypography.body(
                              color: inkColor,
                              size: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // „Gekocht!" verbucht die verwendeten Zutaten in einem Schritt.
            if (recipe.uses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                child: FilledButton.icon(
                  onPressed: () => _openCookedSheet(context),
                  icon: const Icon(Icons.restaurant, size: 18),
                  label: const Text('Gekocht! Zutaten verbuchen'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    required this.color,
    required this.sub,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: sub),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _IngredientBlock extends StatelessWidget {
  const _IngredientBlock({
    required this.title,
    required this.items,
    required this.amounts,
    required this.bullet,
    required this.bulletColor,
  });

  final String title;
  final List<String> items;
  final Map<String, String> amounts;
  final String bullet;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lineColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GSTypography.label(color: muteColor),
            ),
            const SizedBox(height: 12),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        bullet,
                        style: TextStyle(
                          color: bulletColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i,
                        style: GSTypography.body(
                          color: inkColor,
                          size: 14,
                        ),
                      ),
                    ),
                    if (amounts[i] != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        amounts[i]!,
                        style: GSTypography.body(
                          color: muteColor,
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
