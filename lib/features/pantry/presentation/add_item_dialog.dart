import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../providers/pantry_providers.dart';

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

class AddItemDialog extends ConsumerStatefulWidget {
  const AddItemDialog({super.key});

  @override
  ConsumerState<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '📦');
  String _category = 'Sonstiges';
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    _emojiCtrl.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
            emoji: _emojiCtrl.text.trim().isEmpty
                ? '📦'
                : _emojiCtrl.text.trim(),
            expiresAt: _expiresAt,
          );
      ref.invalidate(pantryStreamProvider); // ← neu
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
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

    return Dialog(
      backgroundColor: isDark ? GSColors.cardDark : GSColors.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Neues Lebensmittel',
                  style: GSTypography.headline(color: textColor, size: 22),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        controller: _emojiCtrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24),
                        decoration: const InputDecoration(labelText: 'Emoji'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Pflichtfeld'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Marke (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Menge (z.B. „500 g")'),
                ),
                const SizedBox(height: 12),
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
                InkWell(
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
                                ? 'Mindesthaltbar (optional)'
                                : 'MHD: ${_expiresAt!.day.toString().padLeft(2, '0')}.${_expiresAt!.month.toString().padLeft(2, '0')}.${_expiresAt!.year}',
                            style: GSTypography.body(
                                color: textColor, size: 14),
                          ),
                        ),
                        if (_expiresAt != null)
                          IconButton(
                            icon: Icon(Icons.close, color: subtleColor),
                            onPressed: () =>
                                setState(() => _expiresAt = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                            : const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}