import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../pantry/domain/pantry_categories.dart';
import '../../data/product_emoji.dart';
import '../../domain/recognized_grocery.dart';

/// Kompakter Editor für Name + Kategorie eines erkannten Items.
/// Liefert das angepasste Item zurück (oder null bei Abbruch).
class GroceryEditDialog extends StatefulWidget {
  const GroceryEditDialog({super.key, required this.item});
  final RecognizedGrocery item;

  @override
  State<GroceryEditDialog> createState() => _GroceryEditDialogState();
}

class _GroceryEditDialogState extends State<GroceryEditDialog> {
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
    final tone = GSTone.of(context);

    return AlertDialog(
      backgroundColor: tone.isDark ? GSColors.surfaceDark : GSColors.bgApp,
      title: Text(
        'Bearbeiten',
        style: GSTypography.headline(color: tone.ink, size: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: GSTypography.body(color: tone.ink, size: 15),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: GSTypography.body(color: tone.inkMute, size: 13),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: tone.surface,
                style: GSTypography.body(color: tone.ink, size: 15),
                icon: Icon(Icons.keyboard_arrow_down, color: tone.inkMute),
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
          child: Text('Abbrechen', style: TextStyle(color: tone.inkMute)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
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
