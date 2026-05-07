import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/expiry_dot.dart';
import '../../../core/widgets/gs_app_bar.dart';
import '../domain/pantry_item.dart';
import '../providers/pantry_providers.dart';
import 'add_item_dialog.dart';
import '../../scanner/presentation/scanner_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    final asyncItems = ref.watch(pantryStreamProvider);
    final expiring = ref.watch(expiringSoonProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab-add',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddItemDialog(),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? GSColors.cardDark
                : GSColors.cardLight,
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? GSColors.paper
                : GSColors.forest,
            child: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab-scan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
            backgroundColor: GSColors.primary,
            foregroundColor: GSColors.paper,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scannen'),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncItems.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Fehler beim Laden:\n$e',
                style: GSTypography.body(color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (items) => Column(
            children: [
              GSAppBar(
                subtitle: 'Mein Vorrat',
                title: '${items.length} Lebensmittel',
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: GSColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('synchronisiert',
                        style: GSTypography.body(
                            color: subtleColor, size: 12)),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(textColor: textColor, subtleColor: subtleColor)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 96),
                        children: [
                          if (expiring.isNotEmpty)
                            _ExpiryWarning(items: expiring),
                          _FilterChips(
                            value: _filter,
                            onChanged: (v) => setState(() => _filter = v),
                          ),
                          ..._buildGroups(items, isDark, subtleColor),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroups(
      List<PantryItem> all, bool isDark, Color subtleColor) {
    var list = all;
    if (_filter == 'expiring') {
      list = list.where((p) {
        final d = p.daysUntilExpiry;
        return d != null && d <= 3;
      }).toList();
    } else if (_filter != 'all') {
      list = list.where((p) => p.category == _filter).toList();
    }

    final grouped = <String, List<PantryItem>>{};
    for (final p in list) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }
    grouped.removeWhere((_, items) => items.isEmpty);

    final widgets = <Widget>[];
    grouped.forEach((cat, group) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: Text(
          '${cat.toUpperCase()} · ${group.length}',
          style: GSTypography.label(color: subtleColor),
        ),
      ));
      for (final item in group) {
        widgets.add(_PantryItemCard(item: item));
      }
      widgets.add(const SizedBox(height: 10));
    });
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _PantryItemCard extends ConsumerWidget {
  const _PantryItemCard({required this.item});
  final PantryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: GSColors.expiryUrgent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: GSColors.paper),
      ),
      confirmDismiss: (_) async {
        // Erst löschen, dann Stream invalidieren — der nächste Stream-Tick
        // entfernt das Item aus der Liste, Flutter merkt das und nimmt das
        // Dismissible sauber raus.
        try {
          await ref.read(pantryRepositoryProvider).delete(item.id);
          ref.invalidate(pantryStreamProvider);
          return true; // Wisch wird "bestätigt", Widget verschwindet
        } catch (e) {
          // Bei Fehler nicht wegwischen
          return false;
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? GSColors.cardDark : GSColors.cardLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (isDark ? Colors.white : GSColors.forest)
                .withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : GSColors.sand,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
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
                      color: textColor,
                      size: 14.5,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [item.brand, item.quantity].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GSTypography.body(color: subtleColor, size: 12),
                  ),
                ],
              ),
            ),
            ExpiryDot(days: item.daysUntilExpiry),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _ExpiryWarning extends StatelessWidget {
  const _ExpiryWarning({required this.items});
  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A2622) : const Color(0xFFFBEAE3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? GSColors.expiryUrgent.withValues(alpha: 0.25)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('⏳', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? "Produkt läuft" : "Produkte laufen"} bald ab',
                  style: GSTypography.body(
                    color: textColor,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  items.take(3).map((e) => e.name).join(' · '),
                  style: GSTypography.body(color: subtleColor, size: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;

    const filters = [
      ('all', 'Alles'),
      ('expiring', 'Läuft bald ab'),
      ('Gemüse', 'Gemüse'),
      ('Milchprodukte', 'Milchprodukte'),
      ('Obst', 'Obst'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(f.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: value == f.$1
                        ? (isDark ? GSColors.paper : GSColors.forest)
                        : (isDark ? Colors.white : GSColors.forest)
                            .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: value == f.$1
                          ? (isDark ? GSColors.forest : GSColors.paper)
                          : textColor,
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

// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.textColor, required this.subtleColor});
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Noch nichts im Vorrat',
              textAlign: TextAlign.center,
              style: GSTypography.headline(color: textColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Tippe auf „Hinzufügen", um dein erstes\nLebensmittel anzulegen.',
              textAlign: TextAlign.center,
              style: GSTypography.body(color: subtleColor, size: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}