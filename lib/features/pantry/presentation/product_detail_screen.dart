import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/gs_date_sheet.dart';
import '../../../core/widgets/gs_snackbar.dart';
import '../domain/pantry_item.dart';
import '../domain/quantity_utils.dart';
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
    // Repo & Messenger VOR dem Pop sichern: der Root-Messenger überlebt
    // diesen Screen, damit funktioniert „Rückgängig" auch nach dem Zurück-
    // Navigieren — gleiches Verhalten wie der Swipe in der Liste.
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.archive(_item.id, status: 'consumed');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Kurzer Feier-Moment
      await _showCelebration();
      if (mounted) Navigator.of(context).pop();
      showGsUndoSnack(
        messenger,
        message: '„${_item.name}" als verbraucht markiert',
        onUndo: () => repo.restore(_item.id),
      );
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
        // schließt sich nach 1,4s von selbst — aber nur, wenn der Dialog dann
        // noch offen ist (ctx.mounted), sonst würde der verzögerte pop() die
        // Route treffen, die inzwischen oben liegt (z.B. den Detail-Screen).
        final nav = Navigator.of(ctx);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (ctx.mounted && nav.canPop()) nav.pop();
        });
        // Der Dialog federt mit easeOutBack rein statt hart aufzuploppen —
        // passt zum Feier-Charakter des Moments.
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.scale(
            // easeOutBack überschießt > 1 — für die Opacity klemmen.
            scale: 0.7 + 0.3 * t,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
          child: Dialog(
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
      HapticFeedback.selectionClick();
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

  /// „Teilweise verbraucht": verbucht den gegessenen Anteil als
  /// `consumed` (zählt anteilig in die Statistik, inkl. Rettungs-Logik)
  /// und skaliert das Item auf den Rest ([factor] = was noch da ist).
  ///
  /// Würde der Rest auf 0 runden (z.B. „0,1 Stück" nochmal geviertelt),
  /// ist das Item logisch aufgebraucht → kompletter Verbrauch statt
  /// einer sinnlosen „0,0 Stück"-Leiche im Vorrat.
  Future<void> _adjustPortion(double factor) async {
    final qty = _item.quantity;
    if (qty == null) return;
    final value = leadingQuantityValue(qty);
    if (value == null) return;

    // Anzeige rundet auf eine Nachkommastelle — unter 0,05 wäre der
    // Rest sichtbar „0". Dann ist alles verbraucht.
    if (value * factor < 0.05) {
      await _markConsumed();
      return;
    }

    final remaining = scaleQuantity(qty, factor);
    final consumed = scaleQuantity(qty, 1 - factor);
    if (remaining == null || consumed == null) return;
    final totalCo2 = _item.co2Kg;
    final remainingCo2 = totalCo2 == null ? null : totalCo2 * factor;
    final consumedCo2 = totalCo2 == null ? null : totalCo2 * (1 - factor);

    try {
      await ref.read(pantryRepositoryProvider).consumePartial(
            item: _item,
            remainingQuantity: remaining,
            consumedQuantity: consumed,
            remainingCo2: remainingCo2,
            consumedCo2: consumedCo2,
          );
      HapticFeedback.selectionClick();
      setState(() {
        _item = PantryItem(
          id: _item.id,
          userId: _item.userId,
          name: _item.name,
          category: _item.category,
          emoji: _item.emoji,
          brand: _item.brand,
          quantity: remaining,
          barcode: _item.barcode,
          expiresAt: _item.expiresAt,
          createdAt: _item.createdAt,
          co2Kg: remainingCo2,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$consumed verbucht — noch $remaining übrig.'),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// „1 verbrauchen" für stückzählbare Mengen (2 Mandarinen → 1 essen).
  /// Verbucht genau ein Stück als consumed (anteilige Statistik) und
  /// zählt das Item herunter; das letzte Stück → kompletter Verbrauch.
  Future<void> _consumeOnePiece() async {
    final qty = _item.quantity;
    if (qty == null) return;
    final value = leadingQuantityValue(qty);
    if (value == null) return;
    final count = value.round();
    if (count <= 1) {
      await _markConsumed();
      return;
    }

    final unit = quantityUnit(qty);
    String fmt(int n) => unit == null ? '$n' : '$n $unit';
    final remaining = fmt(count - 1);
    final consumed = fmt(1);
    final totalCo2 = _item.co2Kg;
    final perPiece = totalCo2 == null ? null : totalCo2 / count;
    final remainingCo2 = perPiece == null ? null : perPiece * (count - 1);

    try {
      await ref.read(pantryRepositoryProvider).consumePartial(
            item: _item,
            remainingQuantity: remaining,
            consumedQuantity: consumed,
            remainingCo2: remainingCo2,
            consumedCo2: perPiece,
          );
      HapticFeedback.selectionClick();
      setState(() {
        _item = PantryItem(
          id: _item.id,
          userId: _item.userId,
          name: _item.name,
          category: _item.category,
          emoji: _item.emoji,
          brand: _item.brand,
          quantity: remaining,
          barcode: _item.barcode,
          expiresAt: _item.expiresAt,
          createdAt: _item.createdAt,
          co2Kg: remainingCo2,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$consumed verbucht — noch $remaining übrig.'),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// Baut die „Teilweise verbraucht"-Sektion passend zum Mengen-Typ.
  List<Widget> _buildPortionSection(
    Color inkColor,
    Color muteColor,
    Color lineColor,
  ) {
    final qty = _item.quantity;
    if (qty == null) return const [];
    final value = leadingQuantityValue(qty);
    if (value == null) return const [];

    ButtonStyle chipStyle() => OutlinedButton.styleFrom(
          foregroundColor: inkColor,
          side: BorderSide(color: lineColor),
          minimumSize: const Size.fromHeight(44),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );

    Text chipLabel(String label) => Text(
          label,
          style: GSTypography.body(
            color: inkColor,
            size: 13.5,
            weight: FontWeight.w600,
          ),
        );

    // Stückzählbar: „1 von N verbrauchen".
    if (isCountableQuantity(qty)) {
      final count = value.round();
      if (count < 2) return const []; // 1 Stück → „Verbraucht"-Button
      return [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 10),
          child: Text(
            'STÜCKWEISE VERBRAUCHT?',
            style: GSTypography.label(color: muteColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: OutlinedButton.icon(
            onPressed: _consumeOnePiece,
            icon: Icon(Icons.restaurant, size: 16, color: inkColor),
            label: chipLabel('Eins gegessen — noch $count da'),
            style: chipStyle(),
          ),
        ),
      ];
    }

    // Wiegbar/messbar: Bruch-Chips.
    return [
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 0, 26, 10),
        child: Text(
          'TEILWEISE VERBRAUCHT?',
          style: GSTypography.label(color: muteColor),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            for (final (label, factor) in const [
              ('¾ übrig', 0.75),
              ('½ übrig', 0.5),
              ('¼ übrig', 0.25),
            ]) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _adjustPortion(factor),
                  style: chipStyle(),
                  child: chipLabel(label),
                ),
              ),
              if (factor != 0.25) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    ];
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
            // Endliche Mindestbreite: das Theme-Default (volle Breite)
            // crasht in den unbegrenzten Dialog-Actions.
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Wie bei _markConsumed: Repo & Messenger vor dem Pop sichern,
    // damit „Rückgängig" nach der Navigation noch funktioniert.
    final repo = ref.read(pantryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.archive(_item.id, status: 'discarded');
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
      showGsUndoSnack(
        messenger,
        message: '„${_item.name}" weggeworfen',
        onUndo: () => repo.restore(_item.id),
      );
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
                    tooltip: 'Zurück',
                    onTap: () => Navigator.of(context).pop(),
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                  _CircleButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Produkt löschen',
                    onTap: _delete,
                    surfaceColor: surfaceColor,
                    inkColor: GSColors.accent,
                    lineColor: lineColor,
                  ),
                ],
              ),
            ),

            // Großes Emoji-Tile — Hero-Ziel des kleinen Tiles aus der Liste.
            Center(
              child: Hero(
                tag: 'pantry-emoji-${_item.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: lineColor),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        _item.emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                ),
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
            // Teilweise verbraucht — zwei Modelle je nach Mengen-Typ:
            //  • stückzählbar („2 Stück") → „1 von 2 verbrauchen"
            //  • wiegbar („500 g")        → Bruch-Chips (¾/½/¼ übrig)
            // Bei „1 Stück" oder unparsebarer Menge: gar nichts — dafür
            // gibt es den „Verbraucht"-Button.
            ..._buildPortionSection(inkColor, muteColor, lineColor),
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
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color inkColor;
  final Color lineColor;

  /// Long-Press-Tooltip; dient gleichzeitig als Screenreader-Label
  /// für den ansonsten stummen Icon-Button.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
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
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
