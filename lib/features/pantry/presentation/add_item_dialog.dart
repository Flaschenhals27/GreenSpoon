import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scanner/data/co2_estimator.dart';
import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../scanner/data/product_emoji.dart';
import '../domain/pantry_categories.dart';
import '../domain/shelf_life.dart';
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

  /// Einheiten fürs Mengen-Dropdown — Zahl + Einheit ergibt immer
  /// ein parsebares Format („500 g").
  static const _units = ['g', 'kg', 'ml', 'l', 'Stück'];
  String _qtyUnit = 'g';
  String _category = 'Sonstiges';
  DateTime? _expiresAt;
  bool _saving = false;

  /// Baut den Mengen-String („500 g") oder null, wenn nichts eingegeben.
  String? get _quantity {
    final v = _qtyCtrl.text.trim();
    return v.isEmpty ? null : '$v $_qtyUnit';
  }

  /// Geschätzte Haltbarkeit (Fallback, wenn der User kein MHD wählt).
  int? get _estimatedDays => ShelfLife.estimateDays(
        name: _nameCtrl.text,
        category: _category,
      );

  @override
  void initState() {
    super.initState();
    // Der Haltbarkeits-Hinweis im MHD-Feld hängt am getippten Namen.
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
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

    final co2 = Co2Estimator.estimateCo2Kg(
      category: _category,
      quantity: _quantity,
    );

    try {
      await ref.read(pantryRepositoryProvider).add(
            name: _nameCtrl.text.trim(),
            brand:
                _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
            quantity: _quantity,
            category: _category,
            barcode: null,
            emoji: ProductEmojiResolver.resolve(
              name: _nameCtrl.text.trim(),
              category: _category,
            ),
            // Ohne gewähltes MHD: Haltbarkeit schätzen (Frischware) —
            // lange Haltbares bleibt bewusst ohne Datum.
            expiresAt: _expiresAt ??
                ShelfLife.estimateExpiry(
                  name: _nameCtrl.text,
                  category: _category,
                ),
            co2Kg: co2,
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
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final bgColor = tone.bg;

    return Dialog(
      backgroundColor: bgColor,
      // Oben verankert statt mittig: beim Ausfahren der Tastatur bleibt
      // der Dialog stehen, statt nach oben geschoben zu werden — kein
      // Hüpfen beim Tippen (das Name-Feld hat Autofokus).
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
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
            _Field(label: 'Name', controller: _nameCtrl, autofocus: true),
            const SizedBox(height: 10),
            _Field(label: 'Marke', controller: _brandCtrl),
            const SizedBox(height: 10),
            // Menge als Zahlenfeld (öffnet die Zahlentastatur) + Einheit
            // als Dropdown daneben — zusammen z.B. „500 g".
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Menge',
                    controller: _qtyCtrl,
                    hint: 'z.B. 500',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _UnitField(
                  value: _qtyUnit,
                  options: _units,
                  onChanged: (v) => setState(() => _qtyUnit = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CategoryField(
              value: _category,
              options: kPantryCategories,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: tone.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tone.line,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: muteColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _expiresAt != null
                            ? _formatDate(_expiresAt!)
                            // Transparenz: ohne Datum greift die Schätzung.
                            : _estimatedDays != null
                                ? 'MHD wählen — sonst schätzen wir ~$_estimatedDays Tage'
                                : 'MHD wählen (optional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GSTypography.body(
                          color: _expiresAt == null ? muteColor : inkColor,
                          size: 14.5,
                          weight: FontWeight.w500,
                        ),
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
                  child: Text('Abbrechen', style: TextStyle(color: muteColor)),
                ),
                const SizedBox(width: 12),
                // Expanded statt fester Breite: nimmt den Restplatz und
                // kann nie überlaufen (große Systemschrift, schmale Geräte).
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
  const _Field({
    required this.label,
    required this.controller,
    this.autofocus = false,
    this.hint,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final bool autofocus;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

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
            autofocus: autofocus,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.words,
            style: GSTypography.body(color: inkColor, size: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: GSTypography.body(
                color: muteColor.withValues(alpha: 0.7),
                size: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 2, bottom: 6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kompaktes Einheiten-Dropdown neben dem Mengen-Zahlenfeld.
class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Einheit',
            style: GSTypography.body(color: muteColor, size: 11.5),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
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
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

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
          Text(
            'Kategorie',
            style: GSTypography.body(color: muteColor, size: 11.5),
          ),
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
