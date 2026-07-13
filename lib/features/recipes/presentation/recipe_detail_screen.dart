import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/consume_plan.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/domain/quantity_utils.dart';
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

/// Zeile im „Gekocht"-Sheet: ein Vorrats-Item, das zu einer Rezept-Zutat
/// passt. Stückzählbare Items ([countable]) verbuchen eine wählbare Menge;
/// wiegbare mit passender Rezept-Menge ([consumeAmount]) ziehen genau diesen
/// Betrag ab; alle anderen das ganze Item per An-/Abwahl.
class _CookedRow {
  _CookedRow({
    required this.item,
    required this.countable,
    required this.available,
    this.consumeAmount,
    int initialPieces = 1,
  })  : pieces = countable ? initialPieces : 0,
        selected = !countable;

  final PantryItem item;
  final bool countable;
  final int available;

  /// Wiegbarer Teil-Abzug: die abzuziehende Rezept-Menge („200 g"), sonst null
  /// (ganzes Item).
  final String? consumeAmount;

  /// Stückzählbar: 0..[available].
  int pieces;

  /// Nicht stückzählbar: ganzes Item verbrauchen?
  bool selected;

  /// Wird beim Verbuchen berücksichtigt.
  bool get active => countable ? pieces > 0 : selected;
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

  /// Matcht Zutaten gegen den Vorrat: exakt vor beidseitigem contains,
  /// jedes Item höchstens einmal.
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
        rows.add(_rowFor(match, amount: widget.recipe.amounts[use]));
      } else {
        unmatched.add(use);
      }
    }

    setState(() {
      _rows = rows;
      _unmatched = unmatched;
    });
  }

  /// Baut eine Zeile aus Item und (optionaler) Rezept-Menge [amount] („3",
  /// „200 g"): stückzählbar (ab 2 Stück) → Stepper (vorbefüllt); wiegbar mit
  /// passender Einheit → Teil-Abzug; sonst ganzes Item.
  _CookedRow _rowFor(PantryItem item, {String? amount}) {
    final qty = item.quantity;

    final pieceCount = qty != null && isCountableQuantity(qty)
        ? (leadingQuantityValue(qty)?.round() ?? 0)
        : 0;
    if (pieceCount >= 2) {
      final needed = amount != null && isCountableQuantity(amount)
          ? leadingQuantityValue(amount)?.round()
          : null;
      return _CookedRow(
        item: item,
        countable: true,
        available: pieceCount,
        initialPieces: (needed ?? 1).clamp(1, pieceCount),
      );
    }

    String? consumeAmount;
    if (qty != null && amount != null) {
      final plan = planAmountConsumption(quantity: qty, needed: amount);
      if (plan != null && !plan.consumesWhole) consumeAmount = amount;
    }
    return _CookedRow(
      item: item,
      countable: false,
      available: 1,
      consumeAmount: consumeAmount,
    );
  }

  Future<void> _consume() async {
    final rows = _rows;
    if (_saving || rows == null) return;
    final active = rows.where((r) => r.active).toList();
    if (active.isEmpty) return;
    setState(() => _saving = true);

    // Messenger vor dem Pop sichern (die SnackBar überlebt das Sheet).
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      for (final row in active) {
        await _bookRow(repo, row);
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

    final count = active.length;
    if (mounted) Navigator.of(context).pop(count);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? '1 Zutat verbucht. Guten Appetit!'
                : '$count Zutaten verbucht. Guten Appetit!',
          ),
        ),
      );
  }

  /// Verbucht eine Zeile: Teil-Verbrauch bei passender Teilmenge, sonst das
  /// ganze Item als verbraucht archivieren.
  Future<void> _bookRow(PantryRepository repo, _CookedRow row) async {
    final plan = _planFor(row);
    if (plan != null && !plan.consumesWhole) {
      await repo.consumePartial(
        item: row.item,
        remainingQuantity: plan.remainingQuantity!,
        consumedQuantity: plan.consumedQuantity!,
        remainingCo2: plan.remainingCo2,
        consumedCo2: plan.consumedCo2,
      );
      return;
    }
    await repo.archive(row.item.id, status: 'consumed');
  }

  /// Teil-Verbrauchsplan der Zeile — stückweise oder wiegbar; null → es bleibt
  /// beim Ganz-Verbrauch.
  ConsumptionPlan? _planFor(_CookedRow row) {
    final qty = row.item.quantity;
    if (qty == null) return null;
    if (row.countable) {
      return planPieceConsumption(
        quantity: qty,
        pieces: row.pieces,
        totalCo2: row.item.co2Kg,
      );
    }
    final amount = row.consumeAmount;
    if (amount != null) {
      return planAmountConsumption(
        quantity: qty,
        needed: amount,
        totalCo2: row.item.co2Kg,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final bgColor = tone.bg;

    final rows = _rows;
    final activeCount = rows?.where((r) => r.active).length ?? 0;

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
                  _CookedRowTile(
                    row: row,
                    onToggle: () =>
                        setState(() => row.selected = !row.selected),
                    onIncrement: () => setState(() {
                      if (row.pieces < row.available) row.pieces++;
                    }),
                    onDecrement: () => setState(() {
                      if (row.pieces > 0) row.pieces--;
                    }),
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
                  onPressed: (_saving || activeCount == 0) ? null : _consume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
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
                          activeCount == 1
                              ? '1 Zutat verbuchen'
                              : '$activeCount Zutaten verbuchen',
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

/// Eine Zeile im „Gekocht"-Sheet: stückzählbare Items zeigen einen Mengen-
/// Stepper, alle anderen eine An-/Abwahl.
class _CookedRowTile extends StatelessWidget {
  const _CookedRowTile({
    required this.row,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
  });

  final _CookedRow row;
  final VoidCallback onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    final tile = Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(row.item.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSTypography.body(
                    color: tone.ink,
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                if (row.countable) ...[
                  const SizedBox(height: 2),
                  Text(
                    'von ${row.available}${_unitSuffix(row.item.quantity)}',
                    style: GSTypography.body(color: tone.inkMute, size: 12),
                  ),
                ] else if (row.consumeAmount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '− ${row.consumeAmount}',
                    style: GSTypography.body(color: tone.inkMute, size: 12),
                  ),
                ],
              ],
            ),
          ),
          if (row.countable)
            _Stepper(
              value: row.pieces,
              max: row.available,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
            )
          else
            Checkbox(
              value: row.selected,
              activeColor: GSColors.primary,
              onChanged: (_) => onToggle(),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        // Nur ganze Items sind per Tap umschaltbar; beim Stepper übernehmen
        // die −/+ Knöpfe die Interaktion.
        child: row.countable
            ? tile
            : InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onToggle,
                child: tile,
              ),
      ),
    );
  }
}

/// Einheit hinter der Stückzahl für den „von X"-Hinweis, leer wenn keine da ist.
String _unitSuffix(String? quantity) {
  final unit = quantity == null ? null : quantityUnit(quantity);
  return unit == null ? '' : ' $unit';
}

/// Kompakter −/+ Stepper für die verbrauchte Stückzahl (0..[max]).
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          label: 'Eins weniger',
          onTap: value > 0 ? onDecrement : null,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: tone.ink,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          label: 'Eins mehr',
          onTap: value < max ? onIncrement : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? GSColors.primary.withValues(alpha: 0.12)
            : tone.inkMute.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? GSColors.primary : tone.inkMute,
            ),
          ),
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
