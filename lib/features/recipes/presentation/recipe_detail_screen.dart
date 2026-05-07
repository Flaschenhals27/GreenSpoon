import 'package:flutter/material.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_app_bar.dart';
import '../domain/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            GSAppBar(
              subtitle: recipe.meal,
              title: recipe.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            if (recipe.blurb.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  recipe.blurb,
                  style: GSTypography.italicCaption(color: subtleColor)
                      .copyWith(fontSize: 14),
                ),
              ),
            // Meta-Zeile
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  _Meta(
                    icon: Icons.schedule,
                    label: '${recipe.timeMin} Min',
                    color: textColor,
                    sub: subtleColor,
                  ),
                  const SizedBox(width: 24),
                  _Meta(
                    icon: Icons.tune,
                    label: recipe.difficulty,
                    color: textColor,
                    sub: subtleColor,
                  ),
                  const SizedBox(width: 24),
                  _Meta(
                    icon: Icons.people_outline,
                    label: '${recipe.servings} Pers.',
                    color: textColor,
                    sub: subtleColor,
                  ),
                ],
              ),
            ),
            // Tags
            if (recipe.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final t in recipe.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GSColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: GSColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
                bullet: '✓',
                bulletColor: GSColors.primary,
                textColor: textColor,
                subtleColor: subtleColor,
                isDark: isDark,
              ),
            // Zutaten, die fehlen
            if (recipe.missing.isNotEmpty)
              _IngredientBlock(
                title: 'Du brauchst noch',
                items: recipe.missing,
                bullet: '+',
                bulletColor: GSColors.expirySoon,
                textColor: textColor,
                subtleColor: subtleColor,
                isDark: isDark,
              ),
            // Schritte
            if (recipe.steps.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'ZUBEREITUNG',
                  style: GSTypography.label(color: subtleColor),
                ),
              ),
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: GSColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: GSColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            recipe.steps[i],
                            style: GSTypography.body(
                              color: textColor,
                              size: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

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
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}

class _IngredientBlock extends StatelessWidget {
  const _IngredientBlock({
    required this.title,
    required this.items,
    required this.bullet,
    required this.bulletColor,
    required this.textColor,
    required this.subtleColor,
    required this.isDark,
  });

  final String title;
  final List<String> items;
  final String bullet;
  final Color bulletColor;
  final Color textColor;
  final Color subtleColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? GSColors.cardDark : GSColors.cardLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (isDark ? Colors.white : GSColors.forest)
                .withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: GSTypography.label(color: subtleColor)),
            const SizedBox(height: 10),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
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
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i,
                        style: GSTypography.body(
                          color: textColor,
                          size: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}