import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../scanner/data/product_emoji.dart';
import '../providers/pantry_providers.dart';

class AddItemDialog extends ConsumerStatefulWidget {
  const AddItemDialog({super.key});

  @override
  ConsumerState<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<AddItemDialog> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _category = 'Sonstiges';
  DateTime? _expiresAt;
  bool _saving = false;

  static const _categories = [
    'Milchprodukte',
    'Obst',
    'Gemüse',
    'Fleisch & Fisch',
    'Pasta & Reis',
    'Brot & Backwaren',
    'Müsli & Cerealien',
    'Eier',
    'Süßes & Snacks',
    'Gewürze & Saucen',
    'Aufstriche',
    'Konserven',
    'Tiefkühl',
    'Getränke',
    'Sonstiges',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showGSDateSheet(
      context,
      initial: _expiresAt,
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Namen eingeben.')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      await ref.read(pantryRepositoryProvider).add(
            name: _nameCtrl.text.trim(),
            brand: _brandCtrl.text.trim().isEmpty
                ? null
                : _brandCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim().isEmpty
                ? null
                : _qtyCtrl.text.trim(),
            category: _category,
            barcode: null,
            emoji: ProductEmojiResolver.resolve(
              name: _nameCtrl.text.trim(),
              category: _category,
            ),
            expiresAt: _expiresAt,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
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

    return Dialog(
      backgroundColor: bgColor,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NEUES ITEM',
              style: GSTypography.label(color: muteColor),
            ),
            const SizedBox(height: 6),
            Text(
              'Manuell hinzufügen',
              style: GSTypography.headline(color: inkColor, size: 24),
            ),
            const SizedBox(height: 18),
            _Field(label: 'Name', controller: _nameCtrl),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _Field(label: 'Marke', controller: _brandCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: 'Menge', controller: _qtyCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            _CategoryField(
              value: _category,
              options: _categories,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? GSColors.surfaceDark : GSColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? GSColors.lineDark : GSColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: muteColor, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _expiresAt == null
                          ? 'MHD wählen (optional)'
                          : _formatDate(_expiresAt!),
                      style: GSTypography.body(
                        color: _expiresAt == null ? muteColor : inkColor,
                        size: 14.5,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Abbrechen',
                      style: TextStyle(color: muteColor)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    backgroundColor: GSColors.primary,
                    foregroundColor: GSColors.cream,
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
                          'Hinzufügen',
                          style: GSTypography.body(
                            color: GSColors.cream,
                            size: 14.5,
                            weight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GSTypography.body(color: muteColor, size: 11.5)),
          TextField(
            controller: controller,
            style: GSTypography.body(color: inkColor, size: 15),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 2, bottom: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategorie',
              style: GSTypography.body(color: muteColor, size: 11.5)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: surfaceColor,
              style: GSTypography.body(color: inkColor, size: 15),
              icon: Icon(Icons.keyboard_arrow_down, color: muteColor),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}