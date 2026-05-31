import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/expiry_alert.dart';
import '../../../core/widgets/expiry_dot.dart';
import '../../../core/widgets/impact_ribbon.dart';
import '../../auth/providers/auth_providers.dart';
import '../../main_shell.dart';
import '../../profile/providers/profile_providers.dart';
import '../domain/pantry_item.dart';
import '../providers/pantry_providers.dart';
import 'product_detail_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _filter = 'Alle';

  // Diese Kategorien zeigen wir in der Filterleiste.
  // "Alle" und "Läuft bald ab" sind virtuelle Filter, der Rest matcht
  // direkt auf das `category`-Feld der PantryItems.
  static const _categories = [
    'Alle',
    'Läuft bald ab',
    'Obst',
    'Gemüse',
    'Milchprodukte',
    'Fleisch & Fisch',
    'Brot & Backwaren',
    'Pasta & Reis',
    'Müsli & Cerealien',
    'Eier',
    'Süßes & Snacks',
    'Gewürze & Saucen',
    'Aufstriche',
    'Konserven',
    'Tiefkühl',
    'Getränke',
    'Sonstiges',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncItems = ref.watch(pantryStreamProvider);
    final user = ref.watch(currentUserProvider);

    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: asyncItems.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Fehler beim Laden:\n$e',
                textAlign: TextAlign.center,
                style: GSTypography.body(
                  color: isDark ? GSColors.inkDark : GSColors.ink,
                ),
              ),
            ),
          ),
          data: (items) => _buildContent(items, isDark, initial, email),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<PantryItem> allItems,
    bool isDark,
    String initial,
    String email,
  ) {
    final greeting = email.isNotEmpty ? email.split('@').first : 'dir';

    // Bald ablaufende Items für den Alert
    final expiringSoon = allItems.where((p) {
      final d = p.daysUntilExpiry;
      return d != null && d <= 3;
    }).toList();

    // Filter anwenden
    final filtered = _applyFilter(allItems);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            greeting: greeting,
            initial: initial,
            isDark: isDark,
            onAvatarTap: () {
              // Zum Profil-Tab navigieren (Index 2)
              mainShellTabNotifier.value = 2;
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer(
            builder: (context, ref, _) {
              final stats = ref.watch(userStatsProvider);
              return stats.maybeWhen(
                data: (s) => ImpactRibbon(
                  rescuedCount: s.rescued,
                  co2SavedKg: s.co2SavedKg,
                ),
                orElse: () => const ImpactRibbon(rescuedCount: 0),
              );
            },
          ),
        ),
        if (expiringSoon.isNotEmpty)
          SliverToBoxAdapter(
            child: ExpiryAlert(
              count: expiringSoon.length,
              preview: expiringSoon.take(3).map((e) => e.name).join(', '),
              onTap: () => setState(() => _filter = 'Läuft bald ab'),
            ),
          ),
        SliverToBoxAdapter(
          child: _FilterPills(
            categories: _categories,
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            isDark: isDark,
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(isDark: isDark),
          )
        else
          ..._buildGroups(filtered, isDark),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  List<PantryItem> _applyFilter(List<PantryItem> items) {
    if (_filter == 'Alle') return items;
    if (_filter == 'Läuft bald ab') {
      return items.where((p) {
        final d = p.daysUntilExpiry;
        return d != null && d <= 3;
      }).toList();
    }
    return items.where((p) => p.category == _filter).toList();
  }

  List<Widget> _buildGroups(List<PantryItem> items, bool isDark) {
    // Bei aktivem Kategorie-Filter: nur eine Gruppe, kein Eyebrow nötig
    if (_filter != 'Alle' && _filter != 'Läuft bald ab') {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PantryRow(item: items[i]),
              ),
              childCount: items.length,
            ),
          ),
        ),
      ];
    }

    // Bei Alle / Läuft bald ab: nach Frische gruppieren
    final soon = <PantryItem>[];
    final week = <PantryItem>[];
    final later = <PantryItem>[];
    for (final p in items) {
      final d = p.daysUntilExpiry;
      if (d == null) {
        later.add(p);
      } else if (d <= 3) {
        soon.add(p);
      } else if (d <= 14) {
        week.add(p);
      } else {
        later.add(p);
      }
    }

    final widgets = <Widget>[];
    void addGroup(String eyebrow, List<PantryItem> group) {
      if (group.isEmpty) return;
      widgets.add(
        SliverToBoxAdapter(
          child: _GroupHeader(eyebrow: eyebrow, count: group.length),
        ),
      );
      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PantryRow(item: group[i]),
              ),
              childCount: group.length,
            ),
          ),
        ),
      );
    }

    addGroup('BALD FÄLLIG', soon);
    addGroup('INNERHALB VON 2 WOCHEN', week);
    addGroup('LÄNGER HALTBAR', later);
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.initial,
    required this.isDark,
    required this.onAvatarTap,
  });

  final String greeting;
  final String initial;
  final bool isDark;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hallo $greeting',
                style: GSTypography.label(color: muteColor),
              ),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: GSColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GSTypography.headline(
                      color: GSColors.cream,
                      size: 17,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Was hast du\nim Vorrat?',
            style: GSTypography.headline(color: inkColor, size: 34),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.categories,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final List<String> categories;
  final String value;
  final ValueChanged<String> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final inkSoftColor = isDark ? GSColors.inkSoftDark : GSColors.inkSoft;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;
    final creamColor = isDark ? GSColors.inkDark : GSColors.cream;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Row(
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: value == c
                        ? (isDark ? GSColors.cream : inkColor)
                        : Colors.transparent,
                    border: Border.all(
                      color: value == c
                          ? (isDark ? GSColors.cream : inkColor)
                          : lineColor,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    c,
                    style: GSTypography.body(
                      color: value == c
                          ? (isDark ? GSColors.ink : creamColor)
                          : inkSoftColor,
                      size: 14,
                      weight: FontWeight.w600,
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.eyebrow, required this.count});
  final String eyebrow;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(eyebrow, style: GSTypography.label(color: muteColor)),
          Text(
            '$count',
            style: GSTypography.body(
              color: muteColor,
              size: 12,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _PantryRow extends ConsumerWidget {
  const _PantryRow({required this.item});
  final PantryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: GSColors.accent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: GSColors.cream),
      ),
      confirmDismiss: (_) async {
        final reason = await showDialog<String>(
          context: context,
          builder: (_) => const _RemoveReasonDialog(),
        );
        if (reason == null) return false;
        try {
          await ref
              .read(pantryRepositoryProvider)
              .archive(item.id, status: reason);
          return true;
        } catch (_) {
          return false;
        }
      },
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(item: item),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: lineColor),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
          children: [
            _EmojiTile(emoji: item.emoji, category: item.category),
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
                      color: inkColor,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [item.brand, item.quantity]
                        .whereType<String>()
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GSTypography.body(color: muteColor, size: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExpiryDot(days: item.daysUntilExpiry),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Emoji-Tile mit warmer Hintergrundfarbe je nach Kategorie.
class _EmojiTile extends StatelessWidget {
  const _EmojiTile({required this.emoji, required this.category});
  final String emoji;
  final String category;

  static const _categoryColors = <String, Color>{
    'Milchprodukte': Color(0xFFF1E2BB),
    'Obst': Color(0xFFF3DCC8),
    'Gemüse': Color(0xFFCFDCD0),
    'Fleisch & Fisch': Color(0xFFF3DCC8),
    'Pasta & Reis': Color(0xFFF1E2BB),
    'Brot & Backwaren': Color(0xFFF1E2BB),
    'Müsli & Cerealien': Color(0xFFF1E2BB),
    'Eier': Color(0xFFF1E2BB),
    'Süßes & Snacks': Color(0xFFF3DCC8),
    'Gewürze & Saucen': Color(0xFFF1E2BB),
    'Aufstriche': Color(0xFFF1E2BB),
    'Konserven': Color(0xFFCFDCD0),
    'Tiefkühl': Color(0xFFCFDCD0),
    'Getränke': Color(0xFFCFDCD0),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _categoryColors[category] ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : GSColors.surface2);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? bgColor.withValues(alpha: 0.18) : bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Nichts gefunden',
            style: GSTypography.headline(color: inkColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Tipp auf "Scannen" oder probier\neinen anderen Filter.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: muteColor, size: 13.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _RemoveReasonDialog extends StatelessWidget {
  const _RemoveReasonDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Was ist passiert?',
              style: GSTypography.headline(color: inkColor, size: 20),
            ),
            const SizedBox(height: 14),
            _ReasonButton(
              icon: '🍳',
              label: 'Verwertet',
              sub: 'Gegessen oder gekocht',
              color: GSColors.primary,
              onTap: () => Navigator.of(context).pop('consumed'),
            ),
            const SizedBox(height: 8),
            _ReasonButton(
              icon: '⏳',
              label: 'Abgelaufen',
              sub: 'Leider nicht mehr genießbar',
              color: GSColors.accent,
              onTap: () => Navigator.of(context).pop('expired'),
            ),
            const SizedBox(height: 8),
            _ReasonButton(
              icon: '🗑',
              label: 'Einfach entfernen',
              sub: 'Aus der Liste nehmen',
              color: muteColor,
              onTap: () => Navigator.of(context).pop('discarded'),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Abbrechen', style: TextStyle(color: muteColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonButton extends StatelessWidget {
  const _ReasonButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  final String icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GSTypography.body(
                      color: inkColor,
                      size: 14.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: GSTypography.body(color: muteColor, size: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}