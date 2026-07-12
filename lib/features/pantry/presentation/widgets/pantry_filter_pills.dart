import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';

/// Horizontale Filter-Pills über der Vorratsliste („Alle", „Läuft bald ab",
/// belegte Kategorien).
class PantryFilterPills extends StatelessWidget {
  const PantryFilterPills({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<String> categories;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    // Aktive Pill invertiert: dunkle Tinte auf hell / Cream auf dunkel.
    final activeBg = tone.isDark ? GSColors.cream : tone.ink;
    final activeFg = tone.isDark ? GSColors.ink : GSColors.cream;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Row(
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: value == c,
                child: GestureDetector(
                  onTap: () => onChanged(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: value == c ? activeBg : Colors.transparent,
                      border: Border.all(
                        color: value == c ? activeBg : tone.line,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      c,
                      style: GSTypography.body(
                        color: value == c ? activeFg : tone.inkSoft,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
