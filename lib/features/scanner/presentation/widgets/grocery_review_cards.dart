import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../domain/recognized_grocery.dart';

/// Was mit einem bereits vorhandenen Item geschehen soll.
enum ExistingItemAction { ignore, updateDate, addAnyway }

/// Karte für ein neu erkanntes Lebensmittel: an-/abwählbar, Name/Datum
/// editierbar.
class GroceryNewItemCard extends StatelessWidget {
  const GroceryNewItemCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onEditDate,
    required this.onEdit,
  });

  final RecognizedGrocery item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEditDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: selected ? 1 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: tone.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? GSColors.primary.withValues(alpha: 0.45)
                  : tone.line,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _CheckCircle(checked: selected, onTap: onToggle),
                  const SizedBox(width: 8),
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GSTypography.body(
                              color: tone.ink,
                              size: 15.5,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.quantity == null
                                ? item.category
                                : '${item.quantity} · ${item.category}',
                            style: GSTypography.body(
                              color: tone.inkMute,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: tone.inkMute,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Row(
                  children: [
                    _DateChip(date: item.expiresAt, onTap: onEditDate),
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

/// Karte für ein schon vorhandenes Lebensmittel mit Aktions-Auswahl.
class GroceryExistingItemCard extends StatelessWidget {
  const GroceryExistingItemCard({
    super.key,
    required this.item,
    required this.action,
    required this.canUpdateDate,
    required this.onAction,
  });

  final RecognizedGrocery item;
  final ExistingItemAction action;
  final bool canUpdateDate;
  final ValueChanged<ExistingItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.line),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GSTypography.body(
                          color: tone.ink,
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.matchedName == null
                            ? 'Schon im Vorrat'
                            : 'Passt zu „${item.matchedName}"',
                        style:
                            GSTypography.body(color: tone.inkMute, size: 12),
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
                  selected: action == ExistingItemAction.ignore,
                  onTap: () => onAction(ExistingItemAction.ignore),
                ),
                if (canUpdateDate)
                  _ActionChip(
                    label: 'Datum aktualisieren',
                    selected: action == ExistingItemAction.updateDate,
                    onTap: () => onAction(ExistingItemAction.updateDate),
                  ),
                _ActionChip(
                  label: 'Als neu',
                  selected: action == ExistingItemAction.addAnyway,
                  onTap: () => onAction(ExistingItemAction.addAnyway),
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
    final tone = GSTone.of(context);

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
            color: selected ? GSColors.primary : tone.line,
          ),
        ),
        child: Text(
          label,
          style: GSTypography.body(
            color: selected ? GSColors.primary : tone.inkMute,
            size: 12.5,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.onTap});
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: tone.inkMute),
            const SizedBox(width: 6),
            Text(
              date == null ? 'Kein Datum' : _fmt(date!),
              style: GSTypography.body(
                color: date == null ? tone.inkMute : tone.ink,
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
    final tone = GSTone.of(context);
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
            color: checked ? GSColors.primary : tone.line,
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
