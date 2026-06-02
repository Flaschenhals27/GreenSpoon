import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../domain/pantry_item.dart';
import '../providers/pantry_providers.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.item});
  final PantryItem item;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late PantryItem _item;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _markConsumed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(pantryRepositoryProvider)
          .archive(_item.id, status: 'consumed');
      if (!mounted) return;
      // Kurzer Feier-Moment
      await _showCelebration();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showCelebration() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // schließt sich nach 1,4s von selbst
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Dialog(
          backgroundColor: isDark ? GSColors.surfaceDark : GSColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(pose: MascotPose.celebrating, size: 120),
                const SizedBox(height: 12),
                Text(
                  'Stark, gerettet!',
                  style: GSTypography.headline(
                    color: isDark ? GSColors.inkDark : GSColors.ink,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeMhd() async {
    final picked = await showGSDateSheet(context, initial: _item.expiresAt);
    if (picked == null) return;
    try {
      await ref.read(pantryRepositoryProvider).updateExpiry(_item.id, picked);
      // lokalen Stand aktualisieren, damit die Anzeige sofort stimmt
      setState(() {
        _item = PantryItem(
          id: _item.id,
          userId: _item.userId,
          name: _item.name,
          category: _item.category,
          emoji: _item.emoji,
          brand: _item.brand,
          quantity: _item.quantity,
          barcode: _item.barcode,
          expiresAt: picked,
          createdAt: _item.createdAt,
          co2Kg: _item.co2Kg,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Das Produkt wird aus deinem Vorrat entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(pantryRepositoryProvider)
          .archive(_item.id, status: 'discarded');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final days = _item.daysUntilExpiry;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Top-Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).pop(),
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                  _CircleButton(
                    icon: Icons.delete_outline,
                    onTap: _delete,
                    surfaceColor: surfaceColor,
                    inkColor: GSColors.accent,
                    lineColor: lineColor,
                  ),
                ],
              ),
            ),

            // Großes Emoji-Tile
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: lineColor),
                ),
                alignment: Alignment.center,
                child: Text(_item.emoji, style: const TextStyle(fontSize: 64)),
              ),
            ),
            const SizedBox(height: 24),

            // Kategorie + Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _item.category.toUpperCase(),
                    style: GSTypography.label(color: muteColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _item.name,
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                  if ([_item.brand, _item.quantity]
                      .whereType<String>()
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [_item.brand, _item.quantity]
                          .whereType<String>()
                          .join(' · '),
                      style: GSTypography.body(color: muteColor, size: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Status-Card (Countdown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _StatusCard(item: _item, days: days, isDark: isDark),
            ),
            const SizedBox(height: 16),

            // Aktions-Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _markConsumed,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Verbraucht'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? GSColors.primaryMid : GSColors.primary,
                        side: BorderSide(
                          color:
                              (isDark ? GSColors.primaryMid : GSColors.primary)
                                  .withValues(alpha: 0.4),
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _changeMhd,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: const Text('MHD ändern'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: inkColor,
                        side: BorderSide(color: lineColor),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Details-Liste
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
              child:
                  Text('DETAILS', style: GSTypography.label(color: muteColor)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: lineColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _DetailRow(label: 'Kategorie', value: _item.category),
                    if (_item.brand != null) ...[
                      _DetailDivider(lineColor: lineColor),
                      _DetailRow(label: 'Marke', value: _item.brand!),
                    ],
                    if (_item.quantity != null) ...[
                      _DetailDivider(lineColor: lineColor),
                      _DetailRow(label: 'Menge', value: _item.quantity!),
                    ],
                    if (_item.co2Kg != null) ...[
                      _DetailDivider(lineColor: lineColor),
                      _DetailRow(
                        label: 'CO₂-Fußabdruck',
                        value: '${_item.co2Kg!.toStringAsFixed(1)} kg',
                      ),
                    ],
                    if (_item.barcode != null) ...[
                      _DetailDivider(lineColor: lineColor),
                      _DetailRow(label: 'Barcode', value: _item.barcode!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.item,
    required this.days,
    required this.isDark,
  });
  final PantryItem item;
  final int? days;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    String big;

    if (days == null) {
      bg = isDark ? GSColors.surfaceDark : GSColors.surface;
      fg = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
      label = 'KEIN MHD';
      big = '—';
    } else if (days! < 0) {
      bg = GSColors.accentSoft;
      fg = GSColors.accentDeep;
      label = 'ABGELAUFEN';
      big = '${days!.abs()} T.';
    } else if (days == 0) {
      bg = GSColors.accentSoft;
      fg = GSColors.accentDeep;
      label = 'LÄUFT HEUTE AB';
      big = 'heute';
    } else if (days! <= 2) {
      bg = GSColors.honeySoft;
      fg = const Color(0xFF8A6A17);
      label = 'LÄUFT BALD AB';
      big = '$days T.';
    } else {
      bg = isDark
          ? GSColors.primaryMid.withValues(alpha: 0.15)
          : GSColors.primary.withValues(alpha: 0.10);
      fg = isDark ? GSColors.primaryMid : GSColors.primary;
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
                Text(
                  big,
                  style: GSTypography.headline(color: fg, size: 40),
                ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GSTypography.body(color: muteColor, size: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GSTypography.body(
                color: inkColor,
                size: 14,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider({required this.lineColor});
  final Color lineColor;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: lineColor);
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.surfaceColor,
    required this.inkColor,
    required this.lineColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color inkColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: lineColor),
          ),
          child: Icon(icon, color: inkColor, size: 22),
        ),
      ),
    );
  }
}
