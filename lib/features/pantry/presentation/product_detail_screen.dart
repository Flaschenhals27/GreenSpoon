import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../../core/widgets/gs_snackbar.dart';
import '../domain/consume_plan.dart';
import '../domain/pantry_item.dart';
import '../domain/quantity_utils.dart';
import '../providers/pantry_providers.dart';
import 'widgets/celebration_dialog.dart';
import 'widgets/product_detail_tiles.dart';
import 'widgets/product_status_card.dart';

/// Detailseite eines Vorrats-Items: Status, Aktionen (verbrauchen, MHD,
/// Teilverbrauch, löschen) und die Detail-Liste.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.item});
  final PantryItem item;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late PantryItem _item;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _markConsumed() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Repo & Messenger vor dem Pop sichern, damit „Rückgängig" auch nach
    // dem Zurück-Navigieren funktioniert (Root-Messenger überlebt den Screen).
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.archive(_item.id, status: 'consumed');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showCelebrationDialog(context);
      if (mounted) Navigator.of(context).pop();
      showGsUndoSnack(
        messenger,
        message: '„${_item.name}" als verbraucht markiert',
        onUndo: () => repo.restore(_item.id),
      );
    } catch (e) {
      _showError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMhd() async {
    final picked = await showGSDateSheet(context, initial: _item.expiresAt);
    if (picked == null) return;
    try {
      await ref.read(pantryRepositoryProvider).updateExpiry(_item.id, picked);
      HapticFeedback.selectionClick();
      setState(() => _item = _item.copyWith(expiresAt: picked));
    } catch (e) {
      _showError(e);
    }
  }

  /// Gemeinsamer Kern von Bruch- und Stück-Verbrauch: verbucht [consumed]
  /// als Rettung/Statistik und skaliert das Item auf [remaining].
  Future<void> _consumePartial({
    required String remaining,
    required String consumed,
    required double? remainingCo2,
    required double? consumedCo2,
  }) async {
    try {
      await ref.read(pantryRepositoryProvider).consumePartial(
            item: _item,
            remainingQuantity: remaining,
            consumedQuantity: consumed,
            remainingCo2: remainingCo2,
            consumedCo2: consumedCo2,
          );
      HapticFeedback.selectionClick();
      setState(
        () => _item = _item.copyWith(quantity: remaining, co2Kg: remainingCo2),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$consumed verbucht — noch $remaining übrig.'),
            ),
          );
      }
    } catch (e) {
      _showError(e);
    }
  }

  /// Bruch-Verbrauch für wiegbare Mengen ([factor] = was übrig bleibt).
  Future<void> _adjustPortion(double factor) async {
    final qty = _item.quantity;
    if (qty == null) return;
    final value = leadingQuantityValue(qty);
    if (value == null) return;

    // Würde der Rest sichtbar auf „0,0" runden, gilt alles als verbraucht.
    if (value * factor < 0.05) {
      await _markConsumed();
      return;
    }

    final remaining = scaleQuantity(qty, factor);
    final consumed = scaleQuantity(qty, 1 - factor);
    if (remaining == null || consumed == null) return;
    final totalCo2 = _item.co2Kg;
    await _consumePartial(
      remaining: remaining,
      consumed: consumed,
      remainingCo2: totalCo2 == null ? null : totalCo2 * factor,
      consumedCo2: totalCo2 == null ? null : totalCo2 * (1 - factor),
    );
  }

  /// „1 verbrauchen" für stückzählbare Mengen; das letzte Stück → komplett.
  Future<void> _consumeOnePiece() async {
    final qty = _item.quantity;
    if (qty == null) return;
    final plan = planPieceConsumption(
      quantity: qty,
      pieces: 1,
      totalCo2: _item.co2Kg,
    );
    if (plan == null) return;
    if (plan.consumesWhole) {
      await _markConsumed();
      return;
    }
    await _consumePartial(
      remaining: plan.remainingQuantity!,
      consumed: plan.consumedQuantity!,
      remainingCo2: plan.remainingCo2,
      consumedCo2: plan.consumedCo2,
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Das Produkt wird aus deinem Vorrat entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            // Endliche Breite nötig — Theme-Default crasht in Dialog-Actions.
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Wie bei _markConsumed: Repo & Messenger vor dem Pop sichern.
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.archive(_item.id, status: 'discarded');
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
      showGsUndoSnack(
        messenger,
        message: '„${_item.name}" weggeworfen',
        onUndo: () => repo.restore(_item.id),
      );
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Scaffold(
      backgroundColor: tone.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Zurück',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  CircleIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Produkt löschen',
                    onTap: _delete,
                    color: GSColors.accent,
                  ),
                ],
              ),
            ),

            // Großes Emoji-Tile — Hero-Ziel des kleinen Tiles aus der Liste.
            Center(
              child: Hero(
                tag: 'pantry-emoji-${_item.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: tone.line),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        _item.emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _item.category.toUpperCase(),
                    style: GSTypography.label(color: tone.inkMute),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _item.name,
                    style: GSTypography.headline(color: tone.ink, size: 32),
                  ),
                  if ([_item.brand, _item.quantity]
                      .whereType<String>()
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [_item.brand, _item.quantity]
                          .whereType<String>()
                          .join(' · '),
                      style: GSTypography.body(color: tone.inkMute, size: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ProductStatusCard(item: _item),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _markConsumed,
                      icon: const Icon(Icons.restaurant, size: 18),
                      label: const Text('Verbraucht'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tone.primary,
                        side: BorderSide(
                          color: tone.primary.withValues(alpha: 0.4),
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _changeMhd,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: const Text('MHD ändern'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tone.ink,
                        side: BorderSide(color: tone.line),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._buildPortionSection(tone),
            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
              child: Text(
                'DETAILS',
                style: GSTypography.label(color: tone.inkMute),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: tone.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tone.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    DetailRow(label: 'Kategorie', value: _item.category),
                    if (_item.brand != null) ...[
                      const DetailDivider(),
                      DetailRow(label: 'Marke', value: _item.brand!),
                    ],
                    if (_item.quantity != null) ...[
                      const DetailDivider(),
                      DetailRow(label: 'Menge', value: _item.quantity!),
                    ],
                    if (_item.co2Kg != null) ...[
                      const DetailDivider(),
                      DetailRow(
                        label: 'CO₂-Fußabdruck',
                        value: '${_item.co2Kg!.toStringAsFixed(1)} kg',
                      ),
                    ],
                    if (_item.barcode != null) ...[
                      const DetailDivider(),
                      DetailRow(label: 'Barcode', value: _item.barcode!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// „Teilweise verbraucht"-Sektion: Stück-Button für zählbare Mengen,
  /// Bruch-Chips (¾/½/¼) für wiegbare — sonst nichts.
  List<Widget> _buildPortionSection(GSTone tone) {
    final qty = _item.quantity;
    if (qty == null) return const [];
    final value = leadingQuantityValue(qty);
    if (value == null) return const [];

    ButtonStyle chipStyle() => OutlinedButton.styleFrom(
          foregroundColor: tone.ink,
          side: BorderSide(color: tone.line),
          minimumSize: const Size.fromHeight(44),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );

    Text chipLabel(String label) => Text(
          label,
          style: GSTypography.body(
            color: tone.ink,
            size: 13.5,
            weight: FontWeight.w600,
          ),
        );

    if (isCountableQuantity(qty)) {
      final count = value.round();
      if (count < 2) return const []; // 1 Stück → „Verbraucht"-Button
      return [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 10),
          child: Text(
            'STÜCKWEISE VERBRAUCHT?',
            style: GSTypography.label(color: tone.inkMute),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: OutlinedButton.icon(
            onPressed: _consumeOnePiece,
            icon: Icon(Icons.restaurant, size: 16, color: tone.ink),
            label: chipLabel('Eins gegessen — noch $count da'),
            style: chipStyle(),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 0, 26, 10),
        child: Text(
          'TEILWEISE VERBRAUCHT?',
          style: GSTypography.label(color: tone.inkMute),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            for (final (label, factor) in const [
              ('¾ übrig', 0.75),
              ('½ übrig', 0.5),
              ('¼ übrig', 0.25),
            ]) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _adjustPortion(factor),
                  style: chipStyle(),
                  child: chipLabel(label),
                ),
              ),
              if (factor != 0.25) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    ];
  }
}
