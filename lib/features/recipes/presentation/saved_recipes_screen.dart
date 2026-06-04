import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../domain/recipe.dart';
import '../providers/saved_recipe_providers.dart';
import 'recipe_detail_screen.dart';

/// Übersicht aller vom User gespeicherten Rezepte. Wird aus dem Profil
/// (Abschnitt „Meine Rezepte") geöffnet.
class SavedRecipesScreen extends ConsumerWidget {
  const SavedRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final async = ref.watch(savedRecipesProvider);

    return Scaffold(
      backgroundColor: isDark ? GSColors.bgAppDark : GSColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-Bar mit Back
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Material(
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
                    child: Icon(Icons.chevron_left, color: inkColor, size: 22),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEINE REZEPTE',
                      style: GSTypography.label(color: muteColor),),
                  const SizedBox(height: 8),
                  Text(
                    'Gespeichert',
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => _Centered(
                  child: _Message(
                    pose: MascotPose.searching,
                    title: 'Lädt …',
                    message: 'Deine gespeicherten Rezepte kommen gleich.',
                    inkColor: inkColor,
                    muteColor: muteColor,
                    showSpinner: true,
                  ),
                ),
                error: (e, _) => _Centered(
                  child: _Message(
                    pose: MascotPose.confused,
                    title: 'Konnte nicht laden',
                    message:
                        'Deine Sammlung wollte gerade nicht. Versuch es nochmal.',
                    inkColor: inkColor,
                    muteColor: muteColor,
                    onRetry: () => ref.invalidate(savedRecipesProvider),
                  ),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return _Centered(
                      child: _Message(
                        pose: MascotPose.sleeping,
                        title: 'Noch nichts gespeichert',
                        message:
                            'Tippe bei einem Rezept auf „Speichern", dann\nfindest du es hier wieder.',
                        inkColor: inkColor,
                        muteColor: muteColor,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 32),
                    itemCount: recipes.length,
                    itemBuilder: (context, i) {
                      final r = recipes[i];
                      return _SavedCard(
                        recipe: r,
                        isDark: isDark,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: r),
                          ),
                        ),
                        onRemove: () => _remove(context, ref, r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Recipe r) async {
    final repo = ref.read(savedRecipeRepositoryProvider);
    await repo.unsaveByTitle(r.title);
    ref.invalidate(savedRecipesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('„${r.title}" entfernt'),
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () async {
              await repo.save(r);
              ref.invalidate(savedRecipesProvider);
            },
          ),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.recipe,
    required this.isDark,
    required this.onOpen,
    required this.onRemove,
  });

  final Recipe recipe;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('saved-${recipe.title}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: GSColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: GSColors.accentDeep),
        ),
        child: Material(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lineColor),
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
                            color: inkColor,
                            size: 19,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _MealTag(meal: recipe.meal, muteColor: muteColor),
                    ],
                  ),
                  if (recipe.blurb.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      recipe.blurb,
                      style: GSTypography.body(
                        color: muteColor,
                        size: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: muteColor),
                      const SizedBox(width: 5),
                      Text(
                        '${recipe.timeMin} Min',
                        style: GSTypography.body(color: muteColor, size: 13),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.tune, size: 15, color: muteColor),
                      const SizedBox(width: 5),
                      Text(
                        recipe.difficulty,
                        style: GSTypography.body(color: muteColor, size: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MealTag extends StatelessWidget {
  const _MealTag({required this.meal, required this.muteColor});
  final String meal;
  final Color muteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GSColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        meal,
        style: GSTypography.body(
          color: GSColors.primary,
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: child,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.pose,
    required this.title,
    required this.message,
    required this.inkColor,
    required this.muteColor,
    this.showSpinner = false,
    this.onRetry,
  });

  final MascotPose pose;
  final String title;
  final String message;
  final Color inkColor;
  final Color muteColor;
  final bool showSpinner;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Mascot(pose: pose, size: 140),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GSTypography.headline(color: inkColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GSTypography.body(color: muteColor, size: 14, height: 1.45),
        ),
        if (showSpinner) ...[
          const SizedBox(height: 24),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: GSColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size(180, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: GSColors.primary,
              foregroundColor: GSColors.cream,
            ),
            child: const Text('Erneut versuchen'),
          ),
        ],
      ],
    );
  }
}
