import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_snackbar.dart';
import '../../../core/widgets/mascot.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../domain/recipe.dart';
import 'save_recipe_button.dart';

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
      builder: (_) => _CookedSheet(recipe: recipe),
    );
    if (consumedCount != null && consumedCount > 0 && context.mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Scaffold(
      backgroundColor: isDark ? GSColors.bgAppDark : GSColors.bgApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // Top-Bar mit Back
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
                            color:
                                isDark ? GSColors.primaryMid : GSColors.primary,
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
                bullet: '✓',
                bulletColor: GSColors.primary,
              ),
            // Zutaten, die fehlen
            if (recipe.missing.isNotEmpty)
              _IngredientBlock(
                title: 'Du brauchst noch',
                items: recipe.missing,
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
                            color:
                                isDark ? GSColors.primaryMid : GSColors.primary,
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
            // „Gekocht!" — schließt den Loop: die verwendeten Zutaten
            // werden als verbraucht verbucht, statt dass man jedes Item
            // einzeln im Vorrat suchen und wegwischen muss.
            if (recipe.uses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                child: FilledButton.icon(
                  onPressed: () => _openCookedSheet(context),
                  icon: const Icon(Icons.restaurant, size: 18),
                  label: const Text('Gekocht! Zutaten verbuchen'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    backgroundColor: GSColors.primary,
                    foregroundColor: GSColors.cream,
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

/// Zeile im „Gekocht"-Sheet: ein Vorrats-Item, das zu einer Rezept-Zutat
/// passt, mit An-/Abwählbarkeit.
class _CookedRow {
  _CookedRow({required this.item});
  final PantryItem item;
  bool selected = true;
}

/// Bottom-Sheet nach „Gekocht!": matcht [Recipe.uses] gegen den Vorrat,
/// lässt die Auswahl anpassen und verbucht sie als verbraucht (mit Undo).
class _CookedSheet extends ConsumerStatefulWidget {
  const _CookedSheet({required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<_CookedSheet> createState() => _CookedSheetState();
}

class _CookedSheetState extends ConsumerState<_CookedSheet> {
  List<_CookedRow>? _rows;
  List<String> _unmatched = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Einmalig beim Öffnen matchen — der Vorrat soll sich unterm Sheet
    // nicht live verschieben.
    WidgetsBinding.instance.addPostFrameCallback((_) => _match());
  }

  /// Matcht die Rezept-Zutaten gegen die Vorrats-Items: exakter Name
  /// zuerst, sonst enthält-Beziehung in beide Richtungen („Tomaten" ↔
  /// „Cherry-Tomaten"). Jedes Vorrats-Item höchstens einmal.
  void _match() {
    final pantry = ref.read(pantryStreamProvider).valueOrNull ?? const [];
    final usedIds = <String>{};
    final rows = <_CookedRow>[];
    final unmatched = <String>[];

    PantryItem? findFor(String use) {
      final u = use.trim().toLowerCase();
      for (final p in pantry) {
        if (usedIds.contains(p.id)) continue;
        if (p.name.trim().toLowerCase() == u) return p;
      }
      for (final p in pantry) {
        if (usedIds.contains(p.id)) continue;
        final n = p.name.trim().toLowerCase();
        if (n.contains(u) || u.contains(n)) return p;
      }
      return null;
    }

    for (final use in widget.recipe.uses) {
      final match = findFor(use);
      if (match != null) {
        usedIds.add(match.id);
        rows.add(_CookedRow(item: match));
      } else {
        unmatched.add(use);
      }
    }

    setState(() {
      _rows = rows;
      _unmatched = unmatched;
    });
  }

  Future<void> _consume() async {
    final rows = _rows;
    if (_saving || rows == null) return;
    final selected = rows.where((r) => r.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _saving = true);

    // Repo + Messenger vor dem Pop sichern (Undo überlebt das Sheet).
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ids = selected.map((r) => r.item.id).toList();

    try {
      for (final id in ids) {
        await repo.archive(id, status: 'consumed');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verbuchen hat nicht geklappt — nochmal versuchen.'),
          ),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(ids.length);
    showGsUndoSnack(
      messenger,
      message: ids.length == 1
          ? '1 Zutat verbucht. Guten Appetit!'
          : '${ids.length} Zutaten verbucht. Guten Appetit!',
      onUndo: () {
        for (final id in ids) {
          repo.restore(id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final rows = _rows;
    final selectedCount = rows?.where((r) => r.selected).length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muteColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('GEKOCHT', style: GSTypography.label(color: muteColor)),
              const SizedBox(height: 6),
              Text(
                'Was ist verbraucht?',
                style: GSTypography.headline(color: inkColor, size: 24),
              ),
              const SizedBox(height: 16),
              if (rows == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: GSColors.primary),
                  ),
                )
              else if (rows.isEmpty)
                Column(
                  children: [
                    const Mascot(pose: MascotPose.confused, size: 96),
                    const SizedBox(height: 8),
                    Text(
                      'Keine der Zutaten ist (mehr) in deinem Vorrat — nichts zu verbuchen.',
                      textAlign: TextAlign.center,
                      style: GSTypography.body(
                        color: muteColor,
                        size: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                )
              else ...[
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            setState(() => row.selected = !row.selected),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: lineColor),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Text(
                                  row.item.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  row.item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GSTypography.body(
                                    color: inkColor,
                                    size: 14.5,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: row.selected,
                                activeColor: GSColors.primary,
                                onChanged: (v) => setState(
                                  () => row.selected = v ?? false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_unmatched.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nicht im Vorrat gefunden: ${_unmatched.join(', ')}',
                    style: GSTypography.body(
                      color: muteColor,
                      size: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_saving || selectedCount == 0) ? null : _consume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
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
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: GSColors.cream,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          selectedCount == 1
                              ? '1 Zutat verbuchen'
                              : '$selectedCount Zutaten verbuchen',
                        ),
                ),
              ],
            ],
          ),
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
    required this.bullet,
    required this.bulletColor,
  });

  final String title;
  final List<String> items;
  final String bullet;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
