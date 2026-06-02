import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../main_shell.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import 'recipe_detail_screen.dart';
import '../providers/recipe_cooldown_provider.dart';
import '../../../core/widgets/mascot.dart';

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
            await refreshRecipes(ref);
            try {
              await ref.read(recipesProvider.future);
            } catch (_) {
              // RefreshIndicator soll nicht stehen bleiben, wenn Error
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(isDark: isDark, ref: ref)),
              // Beim (Re-)Laden immer den Ladezustand zeigen, auch wenn noch
// alte Daten im Provider stecken (invalidate behält sie sonst).
              if (asyncRecipes.isLoading)
                SliverToBoxAdapter(child: _LoadingState(color: muteColor))
              else
                asyncRecipes.when(
                  loading: () => SliverToBoxAdapter(
                    child: _LoadingState(color: muteColor),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorOrEmptyState(
                        context, ref, e, inkColor, muteColor),
                  ),
                  data: (recipes) {
                    if (recipes.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoRecipesGeneratedState(
                          textColor: inkColor,
                          subtleColor: muteColor,
                          onRetry: () {
                            if (ref.read(recipeCooldownProvider.notifier).trigger()) {
                              refreshRecipes(ref);
                            }
                          },
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

  /// Wählt zwischen "Vorrat leer" und den drei Error-Varianten.
  Widget _buildErrorOrEmptyState(
    BuildContext context,
    WidgetRef ref,
    Object error,
    Color textColor,
    Color subtleColor,
  ) {
    if (error is PantryEmptyException) {
      return _PantryEmptyState(
        textColor: textColor,
        subtleColor: subtleColor,
      );
    }
    if (error is RecipeException) {
      return _StatusState(
        emoji: _emojiForType(error.type),
        title: _titleForType(error.type),
        message: _messageForType(error.type),
        details: error.details,
        textColor: textColor,
        subtleColor: subtleColor,
        onRetry: () {
          if (ref.read(recipeCooldownProvider.notifier).trigger()) {
            refreshRecipes(ref);
          }
        }
      );
    }
    // Fallback für alles andere (sollte selten passieren)
    return _StatusState(
      emoji: '🤔',
      title: 'Da ist was schiefgelaufen',
      message:
          'Irgendwas hat nicht geklappt. Du kannst es nochmal versuchen — wenn\'s bleibt, schreib uns.',
      details: error.toString(),
      textColor: textColor,
      subtleColor: subtleColor,
      onRetry: () {
        if (ref.read(recipeCooldownProvider.notifier).trigger()) {
          refreshRecipes(ref);
        }
      }
    );
  }

  String _emojiForType(RecipeErrorType t) {
    switch (t) {
      case RecipeErrorType.offline:
        return '📡';
      case RecipeErrorType.geminiDown:
        return '🍳';
      case RecipeErrorType.unknown:
        return '🤔';
    }
  }

  String _titleForType(RecipeErrorType t) {
    switch (t) {
      case RecipeErrorType.offline:
        return 'Keine Verbindung';
      case RecipeErrorType.geminiDown:
        return 'Unsere KI macht gerade Pause';
      case RecipeErrorType.unknown:
        return 'Da ist was schiefgelaufen';
    }
  }

  String _messageForType(RecipeErrorType t) {
    switch (t) {
      case RecipeErrorType.offline:
        return 'Schau mal, ob WLAN oder Mobilfunk an sind — Rezeptvorschläge brauchen Internet.';
      case RecipeErrorType.geminiDown:
        return 'Das passiert manchmal kurz. Versuch\'s in einer Minute nochmal.';
      case RecipeErrorType.unknown:
        return 'Irgendwas hat nicht geklappt. Du kannst es nochmal versuchen — wenn\'s bleibt, schreib uns.';
    }
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
              Consumer(
                builder: (context, ref, _) {
                  final cooldown = ref.watch(recipeCooldownProvider);
                  final onCooldown = cooldown > 0;
                  return GestureDetector(
                    onTap: onCooldown
                        ? null
                        : () {
                            if (ref.read(recipeCooldownProvider.notifier).trigger()) {
                              refreshRecipes(ref);
                            }
                          },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border.all(color: lineColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: onCooldown
                          ? Text(
                              '$cooldown',
                              style: TextStyle(
                                color: muteColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(Icons.refresh, color: inkColor, size: 20),
                    ),
                  );
                },
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
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          const Mascot(pose: MascotPose.searching, size: 140),
          const SizedBox(height: 16),
          Text(
            'Löffeli sucht passende Rezepte …',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Das kann ein paar Sekunden dauern — wir\nbauen die Vorschläge aus deinem Vorrat.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: color, size: 13, height: 1.45),
          ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Allgemeiner Status-Screen mit Emoji, Titel, Beschreibung
/// und optionalem aufklappbarem Technical-Details-Block.
class _StatusState extends StatefulWidget {
  const _StatusState({
    required this.emoji,
    required this.title,
    required this.message,
    required this.textColor,
    required this.subtleColor,
    required this.onRetry,
    this.details,
  });

  final String emoji;
  final String title;
  final String message;
  final String? details;
  final Color textColor;
  final Color subtleColor;
  final VoidCallback onRetry;

  @override
  State<_StatusState> createState() => _StatusStateState();
}

class _StatusStateState extends State<_StatusState> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(pose: MascotPose.confused, size: 150),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: widget.textColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: widget.subtleColor,
              size: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final cooldown = ref.watch(recipeCooldownProvider);
              final onCooldown = cooldown > 0;
              return FilledButton(
                onPressed: onCooldown ? null : widget.onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  backgroundColor: GSColors.primary,
                  foregroundColor: GSColors.cream,
                  disabledBackgroundColor: GSColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: GSColors.cream.withValues(alpha: 0.7),
                ),
                child: Text(onCooldown
                    ? 'Bitte warten … ${cooldown}s'
                    : 'Erneut versuchen'),
              );
            },
          ),
          if (widget.details != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: widget.subtleColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Technische Details',
                    style: GSTypography.body(
                      color: widget.subtleColor,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Text(
                widget.details!,
                textAlign: TextAlign.center,
                style: GSTypography.body(
                  color: widget.subtleColor,
                  size: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Wenn der User keinen Vorrat hat — schickt ihn dezent zum Vorrat-Tab.
class _PantryEmptyState extends StatelessWidget {
  const _PantryEmptyState({
    required this.textColor,
    required this.subtleColor,
  });
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(pose: MascotPose.sleeping, size: 150),
          const SizedBox(height: 16),
          Text(
            'Noch nichts zum Kochen',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: textColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge ein paar Lebensmittel zum Vorrat hinzu, dann\nschlägt dir Löffeli passende Rezepte vor.',
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: subtleColor,
              size: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => mainShellTabNotifier.value = 0,
            style: FilledButton.styleFrom(
              minimumSize: const Size(180, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: GSColors.primary,
              foregroundColor: GSColors.cream,
            ),
            child: const Text('Zum Vorrat'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Vorrat ist da, aber Gemini hat keine Rezepte geliefert (selten,
/// aber nicht ausgeschlossen).
class _NoRecipesGeneratedState extends StatelessWidget {
  const _NoRecipesGeneratedState({
    required this.textColor,
    required this.subtleColor,
    required this.onRetry,
  });
  final Color textColor;
  final Color subtleColor;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(pose: MascotPose.searching, size: 150),
          const SizedBox(height: 16),
          Text(
            'Keine Vorschläge gerade',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: textColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Löffeli hat aus deinem aktuellen Vorrat nichts\ngezaubert. Versuch\'s gleich nochmal.',
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: subtleColor,
              size: 14,
              height: 1.45,
            ),
          ),
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
      ),
    );
  }
}