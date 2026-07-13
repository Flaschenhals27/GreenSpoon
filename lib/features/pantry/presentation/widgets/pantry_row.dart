import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/expiry_dot.dart';
import '../../../../core/widgets/gs_snackbar.dart';
import '../../domain/pantry_item.dart';
import '../../providers/pantry_providers.dart';
import '../product_detail_screen.dart';

/// Eine Zeile der Vorratsliste: Emoji-Tile, Name/Marke/Menge, Ablauf-Chip.
/// Swipe rechts → verbraucht, Swipe links → weggeworfen, Tap → Details.
class PantryRow extends ConsumerWidget {
  const PantryRow({super.key, required this.item});
  final PantryItem item;

  /// Archiviert das Item und zeigt die Undo-SnackBar — genutzt vom Swipe
  /// UND den Screenreader-Aktionen (Wischgesten sind für TalkBack unsichtbar).
  Future<bool> _archive(
    BuildContext context,
    WidgetRef ref, {
    required bool consumed,
  }) async {
    final status = consumed ? 'consumed' : 'discarded';
    // Repo VOR dem Dismiss lesen — danach ist `ref` disposed, der
    // Undo-Button der SnackBar lebt aber weiter.
    final repo = ref.read(pantryRepositoryProvider);
    try {
      await repo.archive(item.id, status: status);
    } catch (_) {
      return false;
    }
    // Spürbarer Commit-Moment: das Item ist jetzt wirklich raus.
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      showGsUndoSnack(
        ScaffoldMessenger.of(context),
        message: consumed
            ? '„${item.name}" als verbraucht markiert'
            : '„${item.name}" weggeworfen',
        onUndo: () => repo.restore(item.id),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      // Nach rechts wischen → verbraucht (grün)
      background: const _SwipeBg(
        color: GSColors.primary,
        icon: Icons.restaurant,
        label: 'Verbraucht',
        alignment: Alignment.centerLeft,
      ),
      // Nach links wischen → weggeworfen (terracotta)
      secondaryBackground: const _SwipeBg(
        color: GSColors.accent,
        icon: Icons.delete_outline,
        label: 'Weggeworfen',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) => _archive(
        context,
        ref,
        consumed: direction == DismissDirection.startToEnd,
      ),
      child: Semantics(
        button: true,
        hint: 'Öffnet die Produktdetails',
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Als verbraucht markieren'): () =>
              _archive(context, ref, consumed: true),
          const CustomSemanticsAction(label: 'Wegwerfen'): () =>
              _archive(context, ref, consumed: false),
        },
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(item: item),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.line),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Hero-Flug zum Detail-Screen; Material(transparency)
                // verhindert den „no Material"-Look unterwegs.
                Hero(
                  tag: 'pantry-emoji-${item.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child:
                        PantryEmojiTile(emoji: item.emoji, category: item.category),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GSTypography.body(
                          color: tone.ink,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (item.brand != null || item.quantity != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [item.brand, item.quantity]
                              .whereType<String>()
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              GSTypography.body(color: tone.inkMute, size: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExpiryDot(days: item.daysUntilExpiry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Emoji-Tile mit warmer Hintergrundfarbe je nach Kategorie.
class PantryEmojiTile extends StatelessWidget {
  const PantryEmojiTile({
    super.key,
    required this.emoji,
    required this.category,
  });
  final String emoji;
  final String category;

  static const _categoryColors = <String, Color>{
    'Milchprodukte': GSColors.honeySoft,
    'Obst': GSColors.accentSoft,
    'Gemüse': GSColors.primarySoft,
    'Fleisch & Fisch': GSColors.accentSoft,
    'Hülsenfrüchte & Tofu': GSColors.primarySoft,
    'Pasta & Reis': GSColors.honeySoft,
    'Brot & Backwaren': GSColors.honeySoft,
    'Backzutaten': GSColors.honeySoft,
    'Müsli & Cerealien': GSColors.honeySoft,
    'Eier': GSColors.honeySoft,
    'Süßes & Snacks': GSColors.accentSoft,
    'Gewürze & Saucen': GSColors.honeySoft,
    'Öle & Fette': GSColors.primarySoft,
    'Aufstriche': GSColors.honeySoft,
    'Konserven': GSColors.primarySoft,
    'Tiefkühl': GSColors.primarySoft,
    'Getränke': GSColors.primarySoft,
  };

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final bgColor = _categoryColors[category] ??
        (tone.isDark ? Colors.white.withValues(alpha: 0.08) : tone.surface2);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: tone.isDark ? bgColor.withValues(alpha: 0.18) : bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      // Rein dekorativ — der Produktname daneben trägt die Information.
      child: ExcludeSemantics(
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Hintergrund, der beim Wischen eines Vorrats-Items sichtbar wird.
class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final left = alignment == Alignment.centerLeft;
    final children = [
      Icon(icon, color: GSColors.cream),
      const SizedBox(width: 10),
      Text(
        label,
        style: GSTypography.body(
          color: GSColors.cream,
          size: 15,
          weight: FontWeight.w700,
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left ? children : children.reversed.toList(),
      ),
    );
  }
}
