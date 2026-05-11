import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    final asyncRecipes = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: GSColors.primary,
          onRefresh: () async {
            ref.invalidate(recipesProvider);
            await ref.read(recipesProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(isDark: isDark, ref: ref)),
              asyncRecipes.when(
                loading: () => SliverToBoxAdapter(
                  child: _LoadingState(color: muteColor),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorState(
                    error: e.toString(),
                    onRetry: () => ref.invalidate(recipesProvider),
                    textColor: inkColor,
                    subtleColor: muteColor,
                  ),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(
                        textColor: inkColor,
                        subtleColor: muteColor,
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildListDelegate(
                      _buildSections(recipes, muteColor, isDark),
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

  List<Widget> _buildSections(
      List<Recipe> recipes, Color muteColor, bool isDark) {
    final sections = ['Frühstück', 'Mittag', 'Abend'];
    final widgets = <Widget>[];
    for (final s in sections) {
      final inSection = recipes.where((r) => r.meal == s).toList();
      if (inSection.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(26, 14, 26, 12),
        child: Text(s.toUpperCase(),
            style: GSTypography.label(color: muteColor)),
      ));
      for (final r in inSection) {
        widgets.add(_RecipeCard(recipe: r));
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.ref});
  final bool isDark;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HEUTE', style: GSTypography.label(color: muteColor)),
              GestureDetector(
                onTap: () => ref.invalidate(recipesProvider),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border.all(color: lineColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.refresh, color: inkColor, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Was kochen wir?',
            style: GSTypography.headline(color: inkColor, size: 34),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: lineColor),
            ),
            padding: const EdgeInsets.all(18),
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
                          color: inkColor,
                          size: 22,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MatchBadge(score: recipe.matchScore),
                  ],
                ),
                if (recipe.blurb.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    recipe.blurb,
                    style: GSTypography.body(
                      color: muteColor,
                      size: 14,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.schedule,
                      label: '${recipe.timeMin} Min',
                      color: muteColor,
                    ),
                    _MetaChip(
                      icon: Icons.tune,
                      label: recipe.difficulty,
                      color: muteColor,
                    ),
                    _MetaChip(
                      icon: Icons.people_outline,
                      label: '${recipe.servings} Pers.',
                      color: muteColor,
                    ),
                  ],
                ),
                if (recipe.missing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: GSColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Du brauchst noch: ${recipe.missing.join(", ")}',
                      style: GSTypography.body(
                        color: GSColors.accentDeep,
                        size: 12.5,
                        weight: FontWeight.w600,
                      ),
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
    Color bg;
    if (score >= 80) {
      color = GSColors.primary;
      bg = GSColors.primary.withValues(alpha: 0.12);
    } else if (score >= 50) {
      color = const Color(0xFF8A6A17);
      bg = GSColors.honey.withValues(alpha: 0.18);
    } else {
      color = GSColors.accentDeep;
      bg = GSColors.accent.withValues(alpha: 0.14);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
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
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
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
          const Icon(Icons.cloud_off, size: 56, color: GSColors.accent),
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
            style: GSTypography.headline(color: textColor, size: 22),
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