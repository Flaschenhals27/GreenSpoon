import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../../shell/shell_providers.dart';
import '../data/recipe_repository.dart';
import '../domain/meal.dart';
import '../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import 'recipe_error_texts.dart';
import 'widgets/entrance.dart';
import 'widgets/meal_colors.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipe_status_views.dart';

/// Rezepte-Tab: KI-generierte Vorschläge aus dem aktuellen Vorrat,
/// gruppiert nach Mahlzeit.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  // Zählt Tab-Besuche → neue Card-Keys → Eintritts-Animation spielt jedes
  // Mal neu (der IndexedStack baut sonst alles unsichtbar vor).
  int _gen = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(shellTabProvider, (_, next) {
      if (next == ShellTab.recipes) setState(() => _gen++);
    });

    final asyncRecipes = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            // Beim (Re-)Laden immer den Ladezustand zeigen, auch wenn noch
            // alte Daten im Provider stecken (invalidate behält sie sonst).
            if (asyncRecipes.isLoading)
              const SliverToBoxAdapter(child: RecipesLoadingView())
            else
              asyncRecipes.when(
                loading: () =>
                    const SliverToBoxAdapter(child: RecipesLoadingView()),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorOrEmptyView(e),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: RecipeStatusView(
                        pose: MascotPose.searching,
                        title: 'Keine Vorschläge gerade',
                        message:
                            'Löffeli hat aus deinem aktuellen Vorrat nichts\ngezaubert. Versuch\'s gleich nochmal.',
                        actionLabel: 'Erneut versuchen',
                        cooldownGated: true,
                        onAction: () => refreshRecipesIfAllowed(ref),
                      ),
                    );
                  }
                  // Vom User per Long-Press gewählte Ersatz-Rezepte überlagern.
                  final overrides = ref.watch(recipeOverridesProvider);
                  final shown =
                      recipes.map((r) => overrides[r.meal] ?? r).toList();
                  final children = _buildSections(shown, _gen);
                  children.add(const RefreshFooter());
                  return SliverList(
                    delegate: SliverChildListDelegate(children),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  /// Wählt zwischen „Vorrat leer" und den Fehler-Varianten.
  Widget _errorOrEmptyView(Object error) {
    if (error is PantryEmptyException) {
      return const PantryEmptyView();
    }
    final type =
        error is RecipeException ? error.type : RecipeErrorType.unknown;
    final details = error is RecipeException ? error.details : error.toString();
    return RecipeStatusView(
      pose: MascotPose.confused,
      title: type.title,
      message: type.message,
      details: details,
      actionLabel: 'Erneut versuchen',
      cooldownGated: true,
      onAction: () => refreshRecipesIfAllowed(ref),
    );
  }

  List<Widget> _buildSections(List<Recipe> recipes, int gen) {
    final widgets = <Widget>[];
    var i = 0;
    for (final meal in Meal.values) {
      final inSection = recipes.where((r) => r.meal == meal).toList();
      if (inSection.isEmpty) continue;
      widgets.add(
        Entrance(
          key: ValueKey('h-$gen-${meal.name}'),
          index: i++,
          child: _SectionHeader(meal: meal),
        ),
      );
      for (final r in inSection) {
        widgets.add(
          Entrance(
            key: ValueKey('card-$gen-${r.meal.name}-${r.title}'),
            index: i++,
            child: RecipeCard(recipe: r),
          ),
        );
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final mc = mealColors(meal);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: mc.ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            meal.label.toUpperCase(),
            style: GSTypography.label(color: mc.ink),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'GUTEN MORGEN';
    if (h < 17) return 'MAHLZEIT';
    return 'GUTEN ABEND';
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting, style: GSTypography.label(color: GSColors.primary)),
          const SizedBox(height: 8),
          Text(
            'Was kochen wir?',
            style: GSTypography.headline(color: tone.ink, size: 34),
          ),
          const SizedBox(height: 6),
          Text(
            'Frische Ideen aus deinem Vorrat 🌿',
            style: GSTypography.body(color: tone.inkMute, size: 14),
          ),
        ],
      ),
    );
  }
}
