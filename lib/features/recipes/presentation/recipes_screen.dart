import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../main_shell.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../../scanner/data/product_emoji.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import 'recipe_detail_screen.dart';
import '../providers/recipe_cooldown_provider.dart';
import '../../../core/widgets/mascot.dart';

// ─── Mahlzeit-Akzente: Farbe + Leit-Emoji je Tageszeit ──────────────────
({Color tint, Color ink}) _mealColors(String meal) {
  switch (meal) {
    case 'Frühstück':
      return (tint: GSColors.honey, ink: const Color(0xFF8A6A17));
    case 'Abend':
      return (tint: GSColors.accent, ink: GSColors.accentDeep);
    default: // Mittag
      return (tint: GSColors.primary, ink: GSColors.primary);
  }
}

String _mealEmoji(String meal) {
  switch (meal) {
    case 'Frühstück':
      return '🥐';
    case 'Abend':
      return '🍲';
    default:
      return '🍽';
  }
}

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

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  // Erhöht sich, sobald der Rezepte-Tab sichtbar wird. Dadurch bekommen die
  // Karten neue Keys → der gestaffelte Auftritt spielt bei jedem Besuch neu.
  // (Nötig, weil der IndexedStack alle Tabs schon beim Start aufbaut und die
  // Animation sonst unsichtbar im Hintergrund abläuft.)
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    mainShellTabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    mainShellTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted && mainShellTabNotifier.value == 1) {
      setState(() => _gen++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    final asyncRecipes = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(isDark: isDark)),
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
                          if (ref
                              .read(recipeCooldownProvider.notifier)
                              .trigger()) {
                            refreshRecipes(ref);
                          }
                        },
                      ),
                    );
                  }
                  // Vom User per Long-Press gewählte Ersatz-Rezepte überlagern.
                  final overrides = ref.watch(recipeOverridesProvider);
                  final shown =
                      recipes.map((r) => overrides[r.meal] ?? r).toList();
                  final children =
                      _buildSections(shown, muteColor, isDark, _gen);
                  children.add(_RefreshFooter(isDark: isDark));
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
          });
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
        });
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
      List<Recipe> recipes, Color muteColor, bool isDark, int gen) {
    final sections = ['Frühstück', 'Mittag', 'Abend'];
    final widgets = <Widget>[];
    var i = 0;
    for (final s in sections) {
      final inSection = recipes.where((r) => r.meal == s).toList();
      if (inSection.isEmpty) continue;
      final mc = _mealColors(s);
      widgets.add(_Entrance(
        key: ValueKey('h-$gen-$s'),
        index: i++,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 14, 26, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: mc.ink, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(s.toUpperCase(), style: GSTypography.label(color: mc.ink)),
            ],
          ),
        ),
      ));
      for (final r in inSection) {
        widgets.add(_Entrance(
          key: ValueKey('card-$gen-${r.meal}-${r.title}'),
          index: i++,
          child: _RecipeCard(recipe: r),
        ));
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark});
  final bool isDark;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'GUTEN MORGEN';
    if (h < 17) return 'MAHLZEIT';
    return 'GUTEN ABEND';
  }

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting, style: GSTypography.label(color: GSColors.primary)),
          const SizedBox(height: 8),
          Text(
            'Was kochen wir?',
            style: GSTypography.headline(color: inkColor, size: 34),
          ),
          const SizedBox(height: 6),
          Text(
            'Frische Ideen aus deinem Vorrat 🌿',
            style: GSTypography.body(color: muteColor, size: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Rezeptkarte mit zwei Gesten:
///  • kurzer Tipp  → Rezept-Detail
///  • 2 Sek. halten → Auswahl-Sheet mit 3 frischen Ideen für diese Mahlzeit.
/// Während des Haltens füllt sich ein Fortschrittsring über der Karte.
class _RecipeCard extends ConsumerStatefulWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends ConsumerState<_RecipeCard>
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
      builder: (_) => _MealAlternativesSheet(meal: widget.recipe.meal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final recipe = widget.recipe;
    final mc = _mealColors(recipe.meal);
    final emojis = _ingredientEmojis(recipe.uses);
    final expiring = ref.watch(expiringSoonProvider);
    final rescue = _rescues(expiring);

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
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: lineColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Zutaten-Motiv + Match (farbiger Streifen je Mahlzeit)
                    Container(
                      color: mc.tint.withValues(alpha: isDark ? 0.22 : 0.12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _EmojiCluster(
                            emojis: emojis,
                            fallback: _mealEmoji(recipe.meal),
                            isDark: isDark,
                          ),
                          const Spacer(),
                          _MatchBadge(score: recipe.matchScore),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _body(inkColor, muteColor, mc, rescue),
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

  /// Findet ein bald ablaufendes Vorrats-Item, das dieses Rezept verwertet.
  String? _rescues(List<dynamic> expiring) {
    for (final item in expiring) {
      final n = (item.name as String).toLowerCase();
      for (final u in widget.recipe.uses) {
        final ul = u.toLowerCase();
        if (ul.contains(n) || n.contains(ul)) {
          final d = item.daysUntilExpiry as int?;
          if (d == null) return item.name as String;
          return '${item.name} · ${d <= 0 ? "heute" : "$d Tg"}';
        }
      }
    }
    return null;
  }

  Widget _body(
    Color inkColor,
    Color muteColor,
    ({Color tint, Color ink}) mc,
    String? rescue,
  ) {
    final recipe = widget.recipe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: GSTypography.headline(
            color: inkColor,
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
                _TagChip(label: t, tint: mc.tint, ink: mc.ink),
            ],
          ),
        ],
        if (recipe.blurb.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            recipe.blurb,
            style: GSTypography.body(color: muteColor, size: 14, height: 1.45),
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
      // Zahl zählt beim Erscheinen von 0 auf den Match-Wert hoch.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Text(
          '${value.round()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Wischt ein Kind beim Erscheinen sanft ein (Fade + leichter Slide).
/// [index] staffelt den Start, sodass Karten nacheinander auftauchen.
class _Entrance extends StatefulWidget {
  const _Entrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 55).clamp(0, 600);
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Überlappende Kreise mit den Emojis der Hauptzutaten.
class _EmojiCluster extends StatelessWidget {
  const _EmojiCluster({
    required this.emojis,
    required this.fallback,
    required this.isDark,
  });
  final List<String> emojis;
  final String fallback;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final list = emojis.isEmpty ? [fallback] : emojis;
    const size = 38.0;
    const overlap = 26.0;
    final bg = isDark ? GSColors.bgAppDark : GSColors.cream;
    final line = isDark ? GSColors.lineDark : GSColors.line;

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
                  border: Border.all(color: line),
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

/// Kleiner farbiger Tag-Chip (z.B. „Vegetarisch", „Schnell").
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.tint, required this.ink});
  final String label;
  final Color tint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            GSTypography.body(color: ink, size: 11.5, weight: FontWeight.w700),
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
                  disabledBackgroundColor:
                      GSColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor:
                      GSColors.cream.withValues(alpha: 0.7),
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

// ─────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────

/// Footer unter der Rezeptliste: Löffeli + Button, der ALLE Rezepte neu
/// vorschlägt. Nutzt denselben Cooldown wie früher der Eckknopf.
class _RefreshFooter extends ConsumerWidget {
  const _RefreshFooter({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final cooldown = ref.watch(recipeCooldownProvider);
    final onCooldown = cooldown > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Column(
        children: [
          const Mascot(pose: MascotPose.waving, size: 96),
          const SizedBox(height: 8),
          Text(
            onCooldown ? 'Einen Moment noch …' : 'Neue Rezepte gewünscht?',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: inkColor, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Tipp: Halte eine Karte gedrückt, um nur\ndiese Mahlzeit neu vorzuschlagen.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: muteColor, size: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCooldown
                ? null
                : () {
                    if (ref.read(recipeCooldownProvider.notifier).trigger()) {
                      refreshRecipes(ref);
                    }
                  },
            icon: Icon(
              onCooldown ? Icons.hourglass_bottom : Icons.refresh,
              size: 18,
            ),
            label: Text(
              onCooldown
                  ? 'Bitte warten … ${cooldown}s'
                  : 'Alle neu vorschlagen',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(220, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: GSColors.primary,
              foregroundColor: GSColors.cream,
              disabledBackgroundColor: GSColors.primary.withValues(alpha: 0.4),
              disabledForegroundColor: GSColors.cream.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Bottom-Sheet mit 3 frischen Alternativen für eine einzelne Mahlzeit.
/// Wird vom 2-Sekunden-Halten auf einer Rezeptkarte geöffnet.
class _MealAlternativesSheet extends ConsumerWidget {
  const _MealAlternativesSheet({required this.meal});
  final String meal;

  String get _mealLabel {
    switch (meal) {
      case 'Mittag':
        return 'Mittagessen';
      case 'Abend':
        return 'Abendessen';
      default:
        return meal;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;
    final async = ref.watch(mealAlternativesProvider(meal));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: lineColor,
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
                            style: GSTypography.label(color: muteColor),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Fürs $_mealLabel',
                            style: GSTypography.headline(
                              color: inkColor,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: muteColor),
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
                    inkColor: inkColor,
                    muteColor: muteColor,
                    showSpinner: true,
                  ),
                  error: (e, _) => _SheetMessage(
                    pose: MascotPose.confused,
                    title: 'Hat nicht geklappt',
                    message:
                        'Die Ideen wollten gerade nicht. Versuch es nochmal.',
                    inkColor: inkColor,
                    muteColor: muteColor,
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
                        inkColor: inkColor,
                        muteColor: muteColor,
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
                          isDark: isDark,
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
            style: GSTypography.headline(color: inkColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GSTypography.body(color: muteColor, size: 13, height: 1.45),
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
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                backgroundColor: GSColors.primary,
                foregroundColor: GSColors.cream,
              ),
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
    required this.isDark,
    required this.onChoose,
    required this.onDetails,
  });

  final Recipe recipe;
  final bool isDark;
  final VoidCallback onChoose;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onChoose,
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
                    _MatchBadge(score: recipe.matchScore),
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
                    _MetaChip(
                      icon: Icons.schedule,
                      label: '${recipe.timeMin} Min',
                      color: muteColor,
                    ),
                    const SizedBox(width: 16),
                    _MetaChip(
                      icon: Icons.tune,
                      label: recipe.difficulty,
                      color: muteColor,
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
