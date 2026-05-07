import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_app_bar.dart';
import '../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    final asyncRecipes = ref.watch(recipesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recipesProvider);
            await ref.read(recipesProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GSAppBar(
                  subtitle: 'Heute',
                  title: 'Was kochen wir?',
                  right: IconButton(
                    icon: Icon(Icons.refresh, color: subtleColor),
                    onPressed: () => ref.invalidate(recipesProvider),
                  ),
                ),
              ),
              asyncRecipes.when(
                loading: () => SliverToBoxAdapter(
                  child: _LoadingState(color: subtleColor),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorState(
                    error: e.toString(),
                    onRetry: () => ref.invalidate(recipesProvider),
                    textColor: textColor,
                    subtleColor: subtleColor,
                  ),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(
                        textColor: textColor,
                        subtleColor: subtleColor,
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildListDelegate(
                      _buildSections(recipes, subtleColor),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(List<Recipe> recipes, Color subtleColor) {
    final sections = ['Frühstück', 'Mittag', 'Abend'];
    final widgets = <Widget>[];
    for (final s in sections) {
      final inSection = recipes.where((r) => r.meal == s).toList();
      if (inSection.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: Text(s.toUpperCase(),
            style: GSTypography.label(color: subtleColor)),
      ));
      for (final r in inSection) {
        widgets.add(_RecipeCard(recipe: r));
      }
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: isDark ? GSColors.cardDark : GSColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        style: GSTypography.headline(
                          color: textColor,
                          size: 18,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MatchBadge(score: recipe.matchScore),
                  ],
                ),
                if (recipe.blurb.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    recipe.blurb,
                    style: GSTypography.body(color: subtleColor, size: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.schedule,
                      label: '${recipe.timeMin} Min',
                      color: subtleColor,
                    ),
                    _MetaChip(
                      icon: Icons.tune,
                      label: recipe.difficulty,
                      color: subtleColor,
                    ),
                    _MetaChip(
                      icon: Icons.people_outline,
                      label: '${recipe.servings} Pers.',
                      color: subtleColor,
                    ),
                  ],
                ),
                if (recipe.missing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Du brauchst noch: ${recipe.missing.join(", ")}',
                    style: GSTypography.body(
                      color: GSColors.expirySoon,
                      size: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = GSColors.primary;
    } else if (score >= 50) {
      color = GSColors.expirySoon;
    } else {
      color = GSColors.expiryUrgent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          const CircularProgressIndicator(color: GSColors.primary),
          const SizedBox(height: 16),
          Text(
            'Gemini denkt nach…',
            style: GSTypography.body(color: color, size: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.textColor,
    required this.subtleColor,
  });
  final String error;
  final VoidCallback onRetry;
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 56, color: GSColors.expirySoon),
          const SizedBox(height: 16),
          Text(
            'Konnte keine Rezepte laden',
            style: GSTypography.headline(color: textColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GSTypography.body(color: subtleColor, size: 12.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.textColor, required this.subtleColor});
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('🥄', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Noch keine Rezepte',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: textColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge ein paar Lebensmittel zum Vorrat hinzu, dann\nschlägt Gemini passende Rezepte vor.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: subtleColor, size: 13),
          ),
        ],
      ),
    );
  }
}