import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../pantry/domain/pantry_item.dart';
import '../../../pantry/providers/pantry_providers.dart';
import '../../../scanner/data/product_emoji.dart';
import '../../domain/recipe.dart';
import '../../domain/rescue_finder.dart';
import '../recipe_detail_screen.dart';
import 'meal_colors.dart';
import 'meal_alternatives_sheet.dart';
import 'recipe_chips.dart';

/// Emojis der Hauptzutaten (dedupliziert, ohne generisches 📦, max. 4).
List<String> _ingredientEmojis(List<String> uses) {
  final out = <String>[];
  final seen = <String>{};
  for (final u in uses) {
    final e = ProductEmojiResolver.resolve(name: u);
    if (e == '📦') continue;
    if (seen.add(e)) out.add(e);
    if (out.length >= 4) break;
  }
  return out;
}

/// Rezeptkarte mit zwei Gesten:
///  • kurzer Tipp  → Rezept-Detail
///  • 2 Sek. halten → Auswahl-Sheet mit 3 frischen Ideen für diese Mahlzeit.
/// Während des Haltens füllt sich ein Fortschrittsring über der Karte.
class RecipeCard extends ConsumerStatefulWidget {
  const RecipeCard({super.key, required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends ConsumerState<RecipeCard>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 2);

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener(_onHoldStatus);

  bool _triggered = false;
  bool _pressed = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _triggered = true;
      HapticFeedback.mediumImpact();
      _openAlternatives();
      _hold.value = 0;
    }
  }

  void _startHold(_) {
    _triggered = false;
    setState(() => _pressed = true);
    _hold.forward(from: 0);
  }

  void _endHold([_]) {
    if (_pressed) setState(() => _pressed = false);
    if (_hold.status == AnimationStatus.forward) _hold.reverse();
  }

  void _onTap() {
    // Nach erfolgreichem Halten NICHT zusätzlich das Detail öffnen.
    if (_triggered) {
      _triggered = false;
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: widget.recipe),
      ),
    );
  }

  void _openAlternatives() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealAlternativesSheet(meal: widget.recipe.meal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final recipe = widget.recipe;
    final mc = mealColors(recipe.meal);
    final emojis = _ingredientEmojis(recipe.uses);
    final expiring = ref.watch(expiringSoonProvider);
    final rescue = _rescueLabel(findRescuedItem(expiring, recipe.uses));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: GestureDetector(
        onTap: _onTap,
        onTapDown: _startHold,
        onTapUp: _endHold,
        onTapCancel: _endHold,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Stack(
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: tone.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: tone.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Zutaten-Motiv + Match (farbiger Streifen je Mahlzeit)
                    Container(
                      color:
                          mc.tint.withValues(alpha: tone.isDark ? 0.22 : 0.12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _EmojiCluster(
                            emojis: emojis,
                            fallback: recipe.meal.emoji,
                          ),
                          const Spacer(),
                          MatchBadge(score: recipe.matchScore),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _body(tone, mc, rescue),
                    ),
                  ],
                ),
              ),
              Positioned.fill(child: _HoldOverlay(progress: _hold)),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatiert den „Rettet …"-Hinweis („Tomaten · 2 Tg" / „… · heute").
  String? _rescueLabel(PantryItem? item) {
    if (item == null) return null;
    final d = item.daysUntilExpiry;
    if (d == null) return item.name;
    return '${item.name} · ${d <= 0 ? "heute" : "$d Tg"}';
  }

  Widget _body(GSTone tone, ({Color tint, Color ink}) mc, String? rescue) {
    final recipe = widget.recipe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: GSTypography.headline(
            color: tone.ink,
            size: 21,
            weight: FontWeight.w500,
          ),
        ),
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in recipe.tags.take(3))
                TagChip(label: t, tint: mc.tint, ink: mc.ink),
            ],
          ),
        ],
        if (recipe.blurb.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            recipe.blurb,
            style:
                GSTypography.body(color: tone.inkMute, size: 14, height: 1.45),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            MetaChip(
              icon: Icons.schedule,
              label: '${recipe.timeMin} Min',
              color: tone.inkMute,
            ),
            MetaChip(
              icon: Icons.tune,
              label: recipe.difficulty,
              color: tone.inkMute,
            ),
            MetaChip(
              icon: Icons.people_outline,
              label: '${recipe.servings} Pers.',
              color: tone.inkMute,
            ),
          ],
        ),
        if (rescue != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: GSColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('♻️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Rettet $rescue',
                    style: GSTypography.body(
                      color: GSColors.primary,
                      size: 12.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (recipe.missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}

/// Überlappende Kreise mit den Emojis der Hauptzutaten.
class _EmojiCluster extends StatelessWidget {
  const _EmojiCluster({required this.emojis, required this.fallback});
  final List<String> emojis;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final list = emojis.isEmpty ? [fallback] : emojis;
    const size = 38.0;
    const overlap = 26.0;
    final bg = tone.isDark ? GSColors.bgAppDark : GSColors.cream;

    return SizedBox(
      height: size,
      width: size + (list.length - 1) * overlap,
      child: Stack(
        children: [
          for (int i = 0; i < list.length; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.line),
                ),
                alignment: Alignment.center,
                child: Text(list[i], style: const TextStyle(fontSize: 19)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Halb-transparenter Overlay über einer Rezeptkarte, dessen Fortschrittsring
/// sich beim Gedrückthalten füllt. Bei voller Füllung wird die Mahlzeit neu
/// vorgeschlagen (siehe [_RecipeCardState]).
class _HoldOverlay extends StatelessWidget {
  const _HoldOverlay({required this.progress});
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final v = progress.value;
          // Erst ab ~100ms Halten sichtbar — so flackert nichts, wenn der
          // Touch eigentlich der Start einer Scroll-Geste war.
          if (v <= 0.05) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: GSColors.primaryDeep.withValues(alpha: 0.6 * v),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 3,
                      color: GSColors.cream,
                      backgroundColor: GSColors.cream.withValues(alpha: 0.30),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: v,
                    child: Text(
                      'Neue Ideen …',
                      style: GSTypography.body(
                        color: GSColors.cream,
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
