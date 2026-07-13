import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../../core/widgets/mascot.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../data/co2_estimator.dart';
import '../domain/recognized_grocery.dart';
import 'widgets/grocery_edit_dialog.dart';
import 'widgets/grocery_review_cards.dart';

/// Ein erkanntes Item plus sein Review-Zustand (Auswahl bzw. Aktion).
class _Row {
  _Row(this.item, {required this.selected, required this.action});
  RecognizedGrocery item;
  bool selected; // nur für neue Items
  ExistingItemAction action; // nur für vorhandene Items
}

/// Review-Sheet nach dem Foto-Scan: zeigt erkannte Lebensmittel in zwei
/// Gruppen (neu / schon im Vorrat) und übernimmt die Auswahl in den Vorrat.
class GroceryReviewSheet extends ConsumerStatefulWidget {
  const GroceryReviewSheet({super.key, required this.items});
  final List<RecognizedGrocery> items;

  @override
  ConsumerState<GroceryReviewSheet> createState() => _GroceryReviewSheetState();
}

class _GroceryReviewSheetState extends ConsumerState<GroceryReviewSheet> {
  late final List<_Row> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.items
        .map(
          (it) => _Row(
            it,
            selected: it.isNew,
            action: ExistingItemAction.ignore,
          ),
        )
        .toList();
  }

  List<_Row> get _newRows => _rows.where((r) => r.item.isNew).toList();
  List<_Row> get _existingRows => _rows.where((r) => !r.item.isNew).toList();

  /// Wie viele Items am Ende neu in den Vorrat wandern.
  int get _addCount =>
      _newRows.where((r) => r.selected).length +
      _existingRows
          .where((r) => r.action == ExistingItemAction.addAnyway)
          .length;

  /// Sucht das passende Vorrats-Item zu einem „schon da"-Treffer.
  PantryItem? _matchedItem(_Row row) {
    final name = row.item.matchedName?.trim().toLowerCase();
    if (name == null || name.isEmpty) return null;
    final pantry = ref.read(pantryStreamProvider).valueOrNull ?? const [];
    for (final p in pantry) {
      if (p.name.trim().toLowerCase() == name) return p;
    }
    return null;
  }

  Future<void> _editDate(_Row row) async {
    final picked = await showGSDateSheet(context, initial: row.item.expiresAt);
    if (picked != null) {
      setState(() => row.item = row.item.copyWith(expiresAt: picked));
    }
  }

  Future<void> _editItem(_Row row) async {
    final result = await showDialog<RecognizedGrocery>(
      context: context,
      builder: (_) => GroceryEditDialog(item: row.item),
    );
    if (result != null) {
      setState(() => row.item = result);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final drafts = <PantryDraft>[];
    void addDraft(RecognizedGrocery it) {
      drafts.add(
        PantryDraft(
          name: it.name,
          quantity: it.quantity,
          category: it.category,
          emoji: it.emoji,
          expiresAt: it.expiresAt,
          co2Kg: Co2Estimator.estimateCo2Kg(
            category: it.category,
            quantity: it.quantity,
          ),
        ),
      );
    }

    for (final r in _newRows) {
      if (r.selected) addDraft(r.item);
    }
    for (final r in _existingRows) {
      if (r.action == ExistingItemAction.addAnyway) addDraft(r.item);
    }

    // Datum-Updates für vorhandene Items sammeln.
    final updates = <(String, DateTime)>[];
    for (final r in _existingRows) {
      if (r.action == ExistingItemAction.updateDate &&
          r.item.expiresAt != null) {
        final match = _matchedItem(r);
        if (match != null) updates.add((match.id, r.item.expiresAt!));
      }
    }

    try {
      final repo = ref.read(pantryRepositoryProvider);
      await repo.addAll(drafts);
      for (final (id, date) in updates) {
        await repo.updateExpiry(id, date);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final newRows = _newRows;
    final existingRows = _existingRows;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.inkMute.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                child: Row(
                  children: [
                    const Mascot(pose: MascotPose.celebrating, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EINKAUF ERKANNT',
                            style: GSTypography.label(color: tone.inkMute),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.items.length} Lebensmittel',
                            style: GSTypography.headline(
                              color: tone.ink,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _rows.isEmpty
                    ? const _EmptyState()
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                        children: [
                          if (newRows.isNotEmpty) ...[
                            const _GroupLabel(text: 'NEU — KOMMT IN DEN VORRAT'),
                            for (final r in newRows)
                              GroceryNewItemCard(
                                item: r.item,
                                selected: r.selected,
                                onToggle: () =>
                                    setState(() => r.selected = !r.selected),
                                onEditDate: () => _editDate(r),
                                onEdit: () => _editItem(r),
                              ),
                          ],
                          if (existingRows.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const _GroupLabel(text: 'SCHON IM VORRAT'),
                            for (final r in existingRows)
                              GroceryExistingItemCard(
                                item: r.item,
                                action: r.action,
                                canUpdateDate: r.item.expiresAt != null &&
                                    _matchedItem(r) != null,
                                onAction: (a) => setState(() => r.action = a),
                              ),
                          ],
                        ],
                      ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tone.line)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        'Abbrechen',
                        style: TextStyle(color: tone.inkMute),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_saving || _addCount == 0) ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
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
                              _addCount == 0
                                  ? 'Nichts ausgewählt'
                                  : '$_addCount hinzufügen',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        text,
        style: GSTypography.label(color: GSTone.of(context).inkMute),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(pose: MascotPose.confused, size: 130),
            const SizedBox(height: 16),
            Text(
              'Nichts erkannt',
              style: GSTypography.headline(color: tone.ink, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Auf dem Foto war kein Lebensmittel zu sehen.\nVersuch es mit besserem Licht nochmal.',
              textAlign: TextAlign.center,
              style: GSTypography.body(
                color: tone.inkMute,
                size: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
