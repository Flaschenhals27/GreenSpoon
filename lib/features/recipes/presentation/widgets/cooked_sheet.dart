import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../pantry/data/pantry_repository.dart';
import '../../../pantry/domain/consume_plan.dart';
import '../../../pantry/domain/pantry_item.dart';
import '../../../pantry/domain/quantity_utils.dart';
import '../../../pantry/providers/pantry_providers.dart';
import '../../domain/ingredient_matcher.dart';
import '../../domain/recipe.dart';

/// Bottom-Sheet nach „Gekocht!": matcht [Recipe.uses] gegen den Vorrat,
/// lässt die Auswahl anpassen und verbucht sie als verbraucht.
/// Poppt die Anzahl der verbuchten Zutaten (null bei Abbruch).
class CookedSheet extends ConsumerStatefulWidget {
  const CookedSheet({super.key, required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<CookedSheet> createState() => _CookedSheetState();
}

/// Zeile im „Gekocht"-Sheet: ein Vorrats-Item, das zu einer Rezept-Zutat
/// passt. Stückzählbare Items ([countable]) verbuchen eine wählbare Menge;
/// wiegbare mit passender Rezept-Menge ([consumeAmount]) ziehen genau diesen
/// Betrag ab; alle anderen das ganze Item per An-/Abwahl.
@immutable
class _CookedRow {
  const _CookedRow({
    required this.item,
    required this.countable,
    required this.available,
    required this.pieces,
    required this.selected,
    this.consumeAmount,
  });

  /// Startzustand: Stückzählbare beginnen mit [initialPieces], ganze Items
  /// sind vorangewählt.
  factory _CookedRow.initial({
    required PantryItem item,
    required bool countable,
    required int available,
    String? consumeAmount,
    int initialPieces = 1,
  }) {
    return _CookedRow(
      item: item,
      countable: countable,
      available: available,
      consumeAmount: consumeAmount,
      pieces: countable ? initialPieces : 0,
      selected: !countable,
    );
  }

  final PantryItem item;
  final bool countable;
  final int available;

  /// Wiegbarer Teil-Abzug: die abzuziehende Rezept-Menge („200 g"), sonst null
  /// (ganzes Item).
  final String? consumeAmount;

  /// Stückzählbar: 0..[available].
  final int pieces;

  /// Nicht stückzählbar: ganzes Item verbrauchen?
  final bool selected;

  /// Wird beim Verbuchen berücksichtigt.
  bool get active => countable ? pieces > 0 : selected;

  _CookedRow copyWith({int? pieces, bool? selected}) {
    return _CookedRow(
      item: item,
      countable: countable,
      available: available,
      consumeAmount: consumeAmount,
      pieces: pieces ?? this.pieces,
      selected: selected ?? this.selected,
    );
  }
}

class _CookedSheetState extends ConsumerState<CookedSheet> {
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

  /// Matcht die Rezept-Zutaten gegen den Vorrat (siehe
  /// [matchIngredientsToPantry]) und baut daraus die Auswahl-Zeilen.
  void _match() {
    final pantry = ref.read(pantryStreamProvider).valueOrNull ?? const [];
    final result = matchIngredientsToPantry(widget.recipe.uses, pantry);

    setState(() {
      _rows = [
        for (final match in result.matches)
          _rowFor(match.item, amount: widget.recipe.amounts[match.ingredient]),
      ];
      _unmatched = result.unmatched;
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
      return _CookedRow.initial(
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
    return _CookedRow.initial(
      item: item,
      countable: false,
      available: 1,
      consumeAmount: consumeAmount,
    );
  }

  /// Ersetzt Zeile [index] durch die angepasste Kopie.
  void _updateRow(int index, _CookedRow row) {
    setState(() => _rows![index] = row);
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
        messenger.showSnackBar(
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
                for (var i = 0; i < rows.length; i++)
                  _CookedRowTile(
                    row: rows[i],
                    onToggle: () => _updateRow(
                      i,
                      rows[i].copyWith(selected: !rows[i].selected),
                    ),
                    onIncrement: () {
                      final row = rows[i];
                      if (row.pieces < row.available) {
                        _updateRow(i, row.copyWith(pieces: row.pieces + 1));
                      }
                    },
                    onDecrement: () {
                      final row = rows[i];
                      if (row.pieces > 0) {
                        _updateRow(i, row.copyWith(pieces: row.pieces - 1));
                      }
                    },
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
