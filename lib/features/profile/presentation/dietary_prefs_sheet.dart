import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../providers/dietary_prefs_providers.dart';

/// Bottom-Sheet zum Auswählen der Diät-Vorlieben.
/// Mehrfachauswahl als Chips, speichert beim Bestätigen.
class DietaryPrefsSheet extends ConsumerStatefulWidget {
  const DietaryPrefsSheet({super.key, required this.initial});
  final List<String> initial;

  @override
  ConsumerState<DietaryPrefsSheet> createState() => _DietaryPrefsSheetState();
}

class _DietaryPrefsSheetState extends ConsumerState<DietaryPrefsSheet> {
  late Set<String> _selected;
  bool _saving = false;

  /// Verfügbare Optionen. Schlüssel = was gespeichert/an Gemini geschickt wird.
  static const _options = [
    'vegetarisch',
    'vegan',
    'laktosefrei',
    'glutenfrei',
    'ohne Nüsse',
    'ohne Schweinefleisch',
    'halal',
    'koscher',
    'pescetarisch',
    'low carb',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.toSet();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(dietaryPrefsRepositoryProvider).save(_selected.toList());
      ref.invalidate(dietaryPrefsProvider);
      if (mounted) Navigator.of(context).pop(true);
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

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text('ERNÄHRUNG', style: GSTypography.label(color: muteColor)),
          const SizedBox(height: 6),
          Text(
            'Worauf sollen wir achten?',
            style: GSTypography.headline(color: inkColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'Löffeli berücksichtigt deine Auswahl bei den Rezeptvorschlägen.',
            style: GSTypography.body(color: muteColor, size: 13.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in _options)
                _Chip(
                  label: opt,
                  selected: _selected.contains(opt),
                  onTap: () {
                    setState(() {
                      if (_selected.contains(opt)) {
                        _selected.remove(opt);
                      } else {
                        _selected.add(opt);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: GSColors.cream,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GSColors.primary : tone.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? GSColors.primary : tone.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, color: GSColors.cream, size: 15),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? GSColors.cream : tone.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
