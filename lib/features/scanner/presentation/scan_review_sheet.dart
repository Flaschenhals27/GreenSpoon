import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mhd_scanner_screen.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../pantry/providers/pantry_providers.dart';
import '../domain/scanned_product.dart';

const _categories = [
  'Gemüse',
  'Obst',
  'Milchprodukte',
  'Fleisch & Fisch',
  'Pasta & Reis',
  'Brot & Backwaren',
  'Tiefkühl',
  'Getränke',
  'Sonstiges',
];

/// Bottom-Sheet zur Bestätigung eines gescannten Produkts.
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
  late String _emoji;
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _brandCtrl = TextEditingController(text: widget.product.brand ?? '');
    _qtyCtrl = TextEditingController(text: widget.product.quantity ?? '');
    _category = _categories.contains(widget.product.category)
        ? widget.product.category
        : 'Sonstiges';
    _emoji = widget.product.emoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('de'),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _scanMhd() async {
    final result = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (_) => const MhdScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _expiresAt = result);
    }
  }

  Future<void> _save() async {
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
            barcode: widget.product.barcode,
            emoji: _emoji,
            expiresAt: _expiresAt,
          );
      ref.invalidate(pantryStreamProvider); // ← neu
      if (mounted) Navigator.of(context).pop();
    }catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);
    final unknown = widget.product.name.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? GSColors.cardDark : GSColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag-Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: subtleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header mit Emoji + Code
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : GSColors.sand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(_emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unknown ? 'Unbekanntes Produkt' : 'Erkannt',
                          style: GSTypography.label(color: subtleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.product.barcode,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: textColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (unknown)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GSColors.expirySoon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Dieses Produkt ist nicht in der Open-Food-Facts-Datenbank. '
                    'Bitte Name und Kategorie selbst angeben.',
                    style: GSTypography.body(
                      color: textColor,
                      size: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),

              // Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),

              // Marke + Menge
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brandCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Marke'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Menge'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Kategorie
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),

              // MHD
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : GSColors.sand,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined, color: subtleColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _expiresAt == null
                                    ? 'MHD wählen'
                                    : '${_expiresAt!.day.toString().padLeft(2, '0')}.${_expiresAt!.month.toString().padLeft(2, '0')}.${_expiresAt!.year}',
                                style: GSTypography.body(color: textColor, size: 14),
                              ),
                            ),
                            if (_expiresAt != null)
                              IconButton(
                                icon: Icon(Icons.close, color: subtleColor),
                                onPressed: () =>
                                    setState(() => _expiresAt = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _scanMhd,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: GSColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.center_focus_strong,
                        color: GSColors.paper,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text('Abbrechen',
                          style: TextStyle(color: subtleColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GSColors.paper,
                              ),
                            )
                          : const Text('Zum Vorrat hinzufügen'),
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
}