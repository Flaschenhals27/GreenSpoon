import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../../core/widgets/mascot.dart';
import '../../pantry/domain/pantry_categories.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../data/co2_estimator.dart';
import '../data/product_emoji.dart';
import '../domain/recognized_grocery.dart';

/// Was mit einem bereits vorhandenen Item geschehen soll.
enum _ExistingAction { ignore, updateDate, addAnyway }

class _Row {
  _Row(this.item, {required this.selected, required this.action});
  RecognizedGrocery item;
  bool selected; // nur für neue Items
  _ExistingAction action; // nur für vorhandene Items
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
            action: _ExistingAction.ignore,
          ),
        )
        .toList();
  }

  List<_Row> get _newRows => _rows.where((r) => r.item.isNew).toList();
  List<_Row> get _existingRows => _rows.where((r) => !r.item.isNew).toList();

  /// Wie viele Items am Ende neu in den Vorrat wandern.
  int get _addCount =>
      _newRows.where((r) => r.selected).length +
      _existingRows.where((r) => r.action == _ExistingAction.addAnyway).length;

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
      builder: (_) => _EditItemDialog(item: row.item),
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
      if (r.action == _ExistingAction.addAnyway) addDraft(r.item);
    }

    // Datum-Updates für vorhandene Items sammeln.
    final updates = <(String, DateTime)>[];
    for (final r in _existingRows) {
      if (r.action == _ExistingAction.updateDate && r.item.expiresAt != null) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;

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
                  color: muteColor.withValues(alpha: 0.4),
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
                            style: GSTypography.label(color: muteColor),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.items.length} Lebensmittel',
                            style: GSTypography.headline(
                              color: inkColor,
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
                    ? _EmptyState(inkColor: inkColor, muteColor: muteColor)
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                        children: [
                          if (newRows.isNotEmpty) ...[
                            _GroupLabel(
                              text: 'NEU — KOMMT IN DEN VORRAT',
                              muteColor: muteColor,
                            ),
                            for (final r in newRows)
                              _NewItemCard(
                                row: r,
                                isDark: isDark,
                                onToggle: () =>
                                    setState(() => r.selected = !r.selected),
                                onEditDate: () => _editDate(r),
                                onEdit: () => _editItem(r),
                              ),
                          ],
                          if (existingRows.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _GroupLabel(
                              text: 'SCHON IM VORRAT',
                              muteColor: muteColor,
                            ),
                            for (final r in existingRows)
                              _ExistingItemCard(
                                row: r,
                                isDark: isDark,
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
                  border: Border(
                    top: BorderSide(
                      color: isDark ? GSColors.lineDark : GSColors.line,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child:
                          Text('Abbrechen', style: TextStyle(color: muteColor)),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_saving || _addCount == 0) ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
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
                              _addCount == 0
                                  ? 'Nichts ausgewählt'
                                  : '$_addCount hinzufügen',
                              style: GSTypography.body(
                                color: GSColors.cream,
                                size: 14.5,
                                weight: FontWeight.w700,
                              ),
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
  const _GroupLabel({required this.text, required this.muteColor});
  final String text;
  final Color muteColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(text, style: GSTypography.label(color: muteColor)),
    );
  }
}

class _NewItemCard extends StatelessWidget {
  const _NewItemCard({
    required this.row,
    required this.isDark,
    required this.onToggle,
    required this.onEditDate,
    required this.onEdit,
  });

  final _Row row;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onEditDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;
    final selected = row.selected;
    final it = row.item;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: selected ? 1 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? GSColors.primary.withValues(alpha: 0.45)
                  : lineColor,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _CheckCircle(checked: selected, onTap: onToggle),
                  const SizedBox(width: 8),
                  Text(it.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.name,
                            style: GSTypography.body(
                              color: inkColor,
                              size: 15.5,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            it.quantity == null
                                ? it.category
                                : '${it.quantity} · ${it.category}',
                            style:
                                GSTypography.body(color: muteColor, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined, color: muteColor, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Row(
                  children: [
                    _DateChip(
                      date: it.expiresAt,
                      onTap: onEditDate,
                      muteColor: muteColor,
                      inkColor: inkColor,
                      lineColor: lineColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingItemCard extends StatelessWidget {
  const _ExistingItemCard({
    required this.row,
    required this.isDark,
    required this.canUpdateDate,
    required this.onAction,
  });

  final _Row row;
  final bool isDark;
  final bool canUpdateDate;
  final ValueChanged<_ExistingAction> onAction;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;
    final it = row.item;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lineColor),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(it.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.name,
                        style: GSTypography.body(
                          color: inkColor,
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        it.matchedName == null
                            ? 'Schon im Vorrat'
                            : 'Passt zu „${it.matchedName}"',
                        style: GSTypography.body(color: muteColor, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _ActionChip(
                  label: 'Ignorieren',
                  selected: row.action == _ExistingAction.ignore,
                  onTap: () => onAction(_ExistingAction.ignore),
                ),
                if (canUpdateDate)
                  _ActionChip(
                    label: 'Datum aktualisieren',
                    selected: row.action == _ExistingAction.updateDate,
                    onTap: () => onAction(_ExistingAction.updateDate),
                  ),
                _ActionChip(
                  label: 'Als neu',
                  selected: row.action == _ExistingAction.addAnyway,
                  onTap: () => onAction(_ExistingAction.addAnyway),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? GSColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? GSColors.primary : lineColor,
          ),
        ),
        child: Text(
          label,
          style: GSTypography.body(
            color: selected ? GSColors.primary : muteColor,
            size: 12.5,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.onTap,
    required this.muteColor,
    required this.inkColor,
    required this.lineColor,
  });
  final DateTime? date;
  final VoidCallback onTap;
  final Color muteColor;
  final Color inkColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: lineColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: muteColor),
            const SizedBox(width: 6),
            Text(
              date == null ? 'Kein Datum' : _fmt(date!),
              style: GSTypography.body(
                color: date == null ? muteColor : inkColor,
                size: 12.5,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? GSColors.primary : Colors.transparent,
          border: Border.all(
            color: checked ? GSColors.primary : lineColor,
            width: 1.5,
          ),
        ),
        child: checked
            ? const Icon(Icons.check, size: 16, color: GSColors.cream)
            : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.inkColor, required this.muteColor});
  final Color inkColor;
  final Color muteColor;

  @override
  Widget build(BuildContext context) {
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
              style: GSTypography.headline(color: inkColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Auf dem Foto war kein Lebensmittel zu sehen.\nVersuch es mit besserem Licht nochmal.',
              textAlign: TextAlign.center,
              style:
                  GSTypography.body(color: muteColor, size: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Kompakter Editor für Name + Kategorie eines erkannten Items.
class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});
  final RecognizedGrocery item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _nameCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _category = kPantryCategories.contains(widget.item.category)
        ? widget.item.category
        : 'Sonstiges';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;

    return AlertDialog(
      backgroundColor: isDark ? GSColors.surfaceDark : GSColors.bgApp,
      title: Text(
        'Bearbeiten',
        style: GSTypography.headline(color: inkColor, size: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: GSTypography.body(color: inkColor, size: 15),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: GSTypography.body(color: muteColor, size: 13),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: surfaceColor,
                style: GSTypography.body(color: inkColor, size: 15),
                icon: Icon(Icons.keyboard_arrow_down, color: muteColor),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
                items: [
                  for (final c in kPantryCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Abbrechen', style: TextStyle(color: muteColor)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: GSColors.primary,
            foregroundColor: GSColors.cream,
          ),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            Navigator.of(context).pop(
              widget.item.copyWith(
                name: name.isEmpty ? widget.item.name : name,
                category: _category,
                emoji: ProductEmojiResolver.resolve(
                  name: name.isEmpty ? widget.item.name : name,
                  category: _category,
                ),
              ),
            );
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
