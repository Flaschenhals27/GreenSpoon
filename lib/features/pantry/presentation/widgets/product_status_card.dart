import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../domain/pantry_item.dart';

/// Countdown-Karte im Produkt-Detail: Farbe/Text je nach Tagen bis MHD.
class ProductStatusCard extends StatelessWidget {
  const ProductStatusCard({super.key, required this.item});
  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final days = item.daysUntilExpiry;
    Color bg;
    Color fg;
    String label;
    String big;

    if (days == null) {
      bg = tone.surface;
      fg = tone.inkMute;
      label = 'KEIN MHD';
      big = '—';
    } else if (days < 0) {
      bg = GSColors.accentSoft;
      fg = GSColors.accentDeep;
      label = 'ABGELAUFEN';
      big = '${days.abs()} T.';
    } else if (days == 0) {
      bg = GSColors.accentSoft;
      fg = GSColors.accentDeep;
      label = 'LÄUFT HEUTE AB';
      big = 'heute';
    } else if (days <= 2) {
      bg = GSColors.honeySoft;
      fg = const Color(0xFF8A6A17);
      label = 'LÄUFT BALD AB';
      big = '$days T.';
    } else {
      bg = tone.primary.withValues(alpha: tone.isDark ? 0.15 : 0.10);
      fg = tone.primary;
      label = 'NOCH HALTBAR';
      big = '$days T.';
    }

    final mhdText = item.expiresAt != null
        ? 'MHD: ${item.expiresAt!.day.toString().padLeft(2, '0')}.${item.expiresAt!.month.toString().padLeft(2, '0')}.${item.expiresAt!.year}'
        : 'Kein Datum gesetzt';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GSTypography.label(color: fg)),
                const SizedBox(height: 6),
                Text(big, style: GSTypography.headline(color: fg, size: 40)),
                const SizedBox(height: 4),
                Text(
                  mhdText,
                  style: GSTypography.body(
                    color: fg.withValues(alpha: 0.75),
                    size: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text('⏳', style: TextStyle(fontSize: 40, color: fg)),
        ],
      ),
    );
  }
}
