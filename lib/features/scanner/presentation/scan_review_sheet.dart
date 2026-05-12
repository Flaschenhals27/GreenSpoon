import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../domain/scanned_product.dart';
import 'mhd_scanner_screen.dart';

class ScanReviewSheet extends ConsumerStatefulWidget {
  const ScanReviewSheet({super.key, required this.product});
  final ScannedProduct product;

  @override
  ConsumerState<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends ConsumerState<ScanReviewSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _qtyCtrl;
  late String _category;
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
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _brandCtrl = TextEditingController(text: widget.product.brand ?? '');
    _qtyCtrl = TextEditingController(text: widget.product.quantity ?? '');
    _category = _categories.contains(widget.product.category)
        ? widget.product.category
        : 'Sonstiges';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateWheel() async {
    final picked = await showGSDateSheet(
      context,
      initial: _expiresAt,
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _scanMhd() async {
    final picked = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (_) => const MhdScannerScreen()),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await ref.read(pantryRepositoryProvider).add(
            name: _nameCtrl.text.trim().isEmpty
                ? 'Unbekannt'
                : _nameCtrl.text.trim(),
            brand: _brandCtrl.text.trim().isEmpty
                ? null
                : _brandCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim().isEmpty
                ? null
                : _qtyCtrl.text.trim(),
            category: _category,
            barcode: widget.product.barcode,
            emoji: widget.product.emoji,
            expiresAt: _expiresAt,
          );
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
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag-Handle
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
              // Header mit Emoji + Erkannt-Info
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: lineColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.product.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ERKANNT',
                          style: GSTypography.label(color: muteColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.barcode,
                          style: GSTypography.body(
                            color: inkColor,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Name
              _Field(
                label: 'Name',
                controller: _nameCtrl,
              ),
              const SizedBox(height: 10),
              // Marke + Menge nebeneinander
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Marke',
                      controller: _brandCtrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: 'Menge',
                      controller: _qtyCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Kategorie
              _CategoryField(
                value: _category,
                options: _categories,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),
              // MHD-Reihe: Picker + Scan-Button
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDateWheel,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: lineColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                color: muteColor, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _expiresAt == null
                                  ? 'MHD wählen'
                                  : _formatDate(_expiresAt!),
                              style: GSTypography.body(
                                color: _expiresAt == null
                                    ? muteColor
                                    : inkColor,
                                size: 14.5,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: GSColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _scanMhd,
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.center_focus_strong,
                          color: GSColors.cream,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Buttons unten
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Abbrechen',
                      style: TextStyle(color: muteColor),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 50),
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
                            'Zum Vorrat hinzufügen',
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