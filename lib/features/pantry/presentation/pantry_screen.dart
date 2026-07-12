import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/utils/display_name.dart';
import '../../../core/widgets/expiry_alert.dart';
import '../../../core/widgets/expiry_dot.dart';
import '../../../core/widgets/gs_snackbar.dart';
import '../../../core/widgets/impact_ribbon.dart';
import '../../auth/providers/auth_providers.dart';
import '../../main_shell.dart';
import '../../profile/presentation/impact_screen.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../domain/pantry_categories.dart';
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

  // Suche: Feld erscheint erst auf Tap (Lupe im Header) — hält den
  // Screen aufgeräumt, solange man nicht sucht.
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  // Zum Erkennen, ob ein Tap INS Suchfeld bzw. auf die Lupe ging —
  // nur Taps daneben sollen die Suche schließen.
  final _searchFieldKey = GlobalKey();
  final _searchIconKey = GlobalKey();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  bool _hitInside(GlobalKey key, Offset globalPos) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(globalPos);
  }

  /// Tap irgendwo außerhalb des Suchfelds:
  ///  - leeres Feld → Suche komplett schließen (Feld war offenbar
  ///    versehentlich offen / wird nicht mehr gebraucht),
  ///  - mit Suchbegriff → nur die Tastatur einklappen; Filter bleibt,
  ///    sonst würde die Ergebnisliste unterm Finger wegspringen.
  void _handlePointerDown(PointerDownEvent event) {
    if (!_searching) return;
    if (_hitInside(_searchFieldKey, event.position) ||
        _hitInside(_searchIconKey, event.position)) {
      return;
    }
    if (_searchCtrl.text.trim().isEmpty) {
      _toggleSearch();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncItems = ref.watch(pantryStreamProvider);
    final user = ref.watch(currentUserProvider);

    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    // Anzeigename: selbst gesetzter Name (Profil) → sonst intelligent aus
    // der E-Mail abgeleitet („fabian.zell@…" → „Fabian") → sonst neutral.
    // Nie das rohe E-Mail-Präfix — „Hallo fabianzell1502" grüßt niemand.
    final rawName = user?.userMetadata?['display_name'];
    final customName = rawName is String ? rawName.trim() : '';
    final displayName = customName.isNotEmpty
        ? customName
        : (deriveDisplayNameFromEmail(email) ?? '');
    final greeting = displayName.isEmpty ? 'Hallo' : 'Hallo $displayName';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: asyncItems.when(
          // Skeleton statt Spinner: die Platzhalter haben dieselbe Höhe wie
          // echte Rows — beim Eintreffen der Daten springt nichts.
          loading: () => _PantrySkeleton(isDark: isDark),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🥄', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 14),
                  Text(
                    'Vorrat konnte nicht geladen werden',
                    textAlign: TextAlign.center,
                    style: GSTypography.headline(
                      color: isDark ? GSColors.inkDark : GSColors.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prüfe deine Verbindung und versuch es nochmal.\n($e)',
                    textAlign: TextAlign.center,
                    style: GSTypography.body(
                      color: isDark ? GSColors.inkMuteDark : GSColors.inkMute,
                      size: 12.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => ref.invalidate(pantryStreamProvider),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(180, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      backgroundColor: GSColors.primary,
                      foregroundColor: GSColors.cream,
                    ),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) => _buildContent(items, isDark, initial, greeting),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<PantryItem> allItems,
    bool isDark,
    String initial,
    String greeting,
  ) {
    // Bald ablaufende Items für den Alert
    final expiringSoon = allItems.where((p) {
      final d = p.daysUntilExpiry;
      return d != null && d <= 3;
    }).toList();

    // Nur Filter anbieten, die auch Treffer hätten: "Alle" immer,
    // "Läuft bald ab" nur bei Bedarf, Kategorien nur wenn belegt.
    // Ein typischer Vorrat nutzt 5-6 der 18 Kategorien — tote Pills
    // wären nur Scroll-Ballast.
    final usedCategories = allItems.map((p) => p.category).toSet();
    final categories = [
      'Alle',
      if (expiringSoon.isNotEmpty) 'Läuft bald ab',
      ...kPantryCategories.where(usedCategories.contains),
    ];
    // Verschwindet der aktive Filter (letztes Item der Kategorie ist weg),
    // fällt die Anzeige auf "Alle" zurück statt leer zu laufen.
    final filter = categories.contains(_filter) ? _filter : 'Alle';

    // Filter + Suche anwenden
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _applyFilter(allItems, filter, query);

    return Listener(
      // Roher Pointer-Hook statt GestureDetector: verliert nie die
      // Gesten-Arena gegen Row-Taps und fängt auch Taps auf leere
      // Flächen (translucent).
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: RefreshIndicator(
        color: GSColors.primary,
        backgroundColor: isDark ? GSColors.surfaceDark : GSColors.surface,
        onRefresh: () async {
          ref.invalidate(pantryStreamProvider);
          // Auf das erste Event des frischen Streams warten, damit der
          // Indikator so lange dreht, wie wirklich geladen wird.
          await ref.read(pantryStreamProvider.future);
        },
        child: CustomScrollView(
          // Auch bei kurzem Inhalt ziehbar — sonst gibt's kein Pull-to-Refresh,
          // wenn nur zwei Items im Vorrat sind.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                greeting: greeting,
                initial: initial,
                isDark: isDark,
                searching: _searching,
                searchIconKey: _searchIconKey,
                onSearchTap: _toggleSearch,
                onAvatarTap: () {
                  // Zum Profil-Tab navigieren (Index 2)
                  mainShellTabNotifier.value = 2;
                },
              ),
            ),
            if (_searching)
              SliverToBoxAdapter(
                child: _SearchField(
                  key: _searchFieldKey,
                  controller: _searchCtrl,
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                  onClose: _toggleSearch,
                ),
              ),
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final stats = ref.watch(userStatsProvider);
                  void openImpact() => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImpactScreen()),
                      );
                  return stats.maybeWhen(
                    data: (s) => ImpactRibbon(
                      ratePercent:
                          s.hasHistory ? (s.useRate * 100).round() : null,
                      onTap: openImpact,
                    ),
                    orElse: () => ImpactRibbon(onTap: openImpact),
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
                categories: categories,
                value: filter,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _filter = v);
                },
                isDark: isDark,
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  isDark: isDark,
                  searching: query.isNotEmpty,
                  // CTA nur, wenn der Vorrat WIRKLICH leer ist (nicht bloß
                  // der Filter) — dann ist Scannen der offensichtliche
                  // nächste Schritt (Onboarding-Anschluss).
                  showScanCta: allItems.isEmpty && query.isEmpty,
                ),
              )
            else
              ..._buildGroups(filtered, filter, isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<PantryItem> _applyFilter(
    List<PantryItem> items,
    String filter,
    String query,
  ) {
    var result = items;
    if (filter == 'Läuft bald ab') {
      result = result.where((p) {
        final d = p.daysUntilExpiry;
        return d != null && d <= 3;
      }).toList();
    } else if (filter != 'Alle') {
      result = result.where((p) => p.category == filter).toList();
    }
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.brand?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return result;
  }

  List<Widget> _buildGroups(
    List<PantryItem> items,
    String filter,
    bool isDark,
  ) {
    // Bei aktivem Kategorie-Filter: nur eine Gruppe, kein Eyebrow nötig
    if (filter != 'Alle' && filter != 'Läuft bald ab') {
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
    required this.searching,
    required this.searchIconKey,
    required this.onSearchTap,
    required this.onAvatarTap,
  });

  final String greeting;
  final String initial;
  final bool isDark;
  final bool searching;

  /// Markiert den Lupen-Button für den „Tap daneben schließt die
  /// Suche"-Handler — ein Tap auf die Lupe selbst darf nicht erst
  /// schließen und dann gleich wieder öffnen.
  final GlobalKey searchIconKey;
  final VoidCallback onSearchTap;
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
            children: [
              Expanded(
                child: Text(
                  greeting,
                  overflow: TextOverflow.ellipsis,
                  style: GSTypography.label(color: muteColor),
                ),
              ),
              Tooltip(
                key: searchIconKey,
                message: searching ? 'Suche schließen' : 'Vorrat durchsuchen',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSearchTap,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        searching ? Icons.close : Icons.search,
                        color: inkColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Profil öffnen',
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: ProfileAvatar(initial: initial, size: 40),
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

/// Suchfeld unterm Header — erscheint nur bei aktiver Suche (Lupe).
class _SearchField extends StatelessWidget {
  const _SearchField({
    super.key,
    required this.controller,
    required this.isDark,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: lineColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, color: muteColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: GSTypography.body(color: inkColor, size: 15),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Name oder Marke suchen …',
                  hintStyle: GSTypography.body(color: muteColor, size: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              Tooltip(
                message: 'Eingabe löschen',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.cancel, color: muteColor, size: 18),
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

  /// Archiviert das Item (verbraucht/weggeworfen) und zeigt die
  /// Undo-SnackBar. Gibt zurück, ob das Archivieren geklappt hat.
  ///
  /// Wird vom Swipe (confirmDismiss) UND von den Screenreader-Aktionen
  /// genutzt — Wischgesten sind für TalkBack/VoiceOver unsichtbar, die
  /// CustomSemanticsActions machen beide Wege ohne Geste erreichbar.
  Future<bool> _archive(
    BuildContext context,
    WidgetRef ref, {
    required bool consumed,
  }) async {
    final status = consumed ? 'consumed' : 'discarded';
    // Repository jetzt auslesen, solange die Row noch im Baum hängt.
    // Nach dem Dismiss wird dieses ConsumerWidget disposed, womit `ref`
    // ungültig wird — die SnackBar (und damit der „Rückgängig"-Button)
    // lebt aber höher im Baum weiter. Würde der Button `ref` benutzen,
    // liefe der restore()-Aufruf auf einem toten WidgetRef ins Leere.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

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
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: lineColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Hero fliegt beim Öffnen der Details zum großen Emoji-Tile.
                // Material(transparency) verhindert den „no Material"-Look
                // des Textes während des Flugs.
                Hero(
                  tag: 'pantry-emoji-${item.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child:
                        _EmojiTile(emoji: item.emoji, category: item.category),
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
                          color: inkColor,
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
                          style: GSTypography.body(color: muteColor, size: 13),
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
class _EmojiTile extends StatelessWidget {
  const _EmojiTile({required this.emoji, required this.category});
  final String emoji;
  final String category;

  static const _categoryColors = <String, Color>{
    'Milchprodukte': Color(0xFFF1E2BB),
    'Obst': Color(0xFFF3DCC8),
    'Gemüse': Color(0xFFCFDCD0),
    'Fleisch & Fisch': Color(0xFFF3DCC8),
    'Hülsenfrüchte & Tofu': Color(0xFFCFDCD0),
    'Pasta & Reis': Color(0xFFF1E2BB),
    'Brot & Backwaren': Color(0xFFF1E2BB),
    'Backzutaten': Color(0xFFF1E2BB),
    'Müsli & Cerealien': Color(0xFFF1E2BB),
    'Eier': Color(0xFFF1E2BB),
    'Süßes & Snacks': Color(0xFFF3DCC8),
    'Gewürze & Saucen': Color(0xFFF1E2BB),
    'Öle & Fette': Color(0xFFCFDCD0),
    'Aufstriche': Color(0xFFF1E2BB),
    'Konserven': Color(0xFFCFDCD0),
    'Tiefkühl': Color(0xFFCFDCD0),
    'Getränke': Color(0xFFCFDCD0),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _categoryColors[category] ??
        (isDark ? Colors.white.withValues(alpha: 0.08) : GSColors.surface2);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? bgColor.withValues(alpha: 0.18) : bgColor,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    this.searching = false,
    this.showScanCta = false,
  });
  final bool isDark;

  /// `true`, wenn gerade eine Suche aktiv ist — dann passt der
  /// Hinweis zur Suche statt zum Scannen.
  final bool searching;

  /// `true`, wenn der Vorrat komplett leer ist — dann führt ein CTA
  /// direkt in den Scan-Flow (Anschluss ans Onboarding).
  final bool showScanCta;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            showScanCta ? '🥬' : (searching ? '🔍' : '🌱'),
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 16),
          Text(
            showScanCta ? 'Dein Vorrat wartet' : 'Nichts gefunden',
            style: GSTypography.headline(color: inkColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            showScanCta
                ? 'Scanne deinen ersten Einkauf — ab dann\nbehalten wir die Haltbarkeit im Blick.'
                : searching
                    ? 'Kein Treffer für deine Suche —\nprobier einen anderen Begriff.'
                    : 'Tipp auf "Scannen" oder probier\neinen anderen Filter.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: muteColor, size: 13.5),
          ),
          if (showScanCta) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => mainShellScanRequest.value++,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Erstes Produkt scannen'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(230, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                backgroundColor: GSColors.primary,
                foregroundColor: GSColors.cream,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Skeleton-Zustand fürs erste Laden: Platzhalter in der Geometrie echter
/// Rows (48er-Tile, zwei Textzeilen), die sanft pulsieren. Kein Layout-
/// Sprung, wenn die Daten eintreffen — und wirkt schneller als ein Spinner.
class _PantrySkeleton extends StatefulWidget {
  const _PantrySkeleton({required this.isDark});
  final bool isDark;

  @override
  State<_PantrySkeleton> createState() => _PantrySkeletonState();
}

class _PantrySkeletonState extends State<_PantrySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        widget.isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = widget.isDark ? GSColors.lineDark : GSColors.line;
    final boneColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : GSColors.surface2;

    Widget bone({required double width, required double height, double r = 6}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: boneColor,
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return Semantics(
      label: 'Vorrat wird geladen',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            children: [
              // Header-Platzhalter (Gruß + Headline)
              bone(width: 90, height: 12),
              const SizedBox(height: 16),
              bone(width: 220, height: 30, r: 8),
              const SizedBox(height: 8),
              bone(width: 160, height: 30, r: 8),
              const SizedBox(height: 24),
              // Impact-Ribbon-Platzhalter
              bone(width: double.infinity, height: 42, r: 14),
              const SizedBox(height: 18),
              // Filter-Pills-Platzhalter
              Row(
                children: [
                  for (final w in [64.0, 110.0, 88.0, 72.0]) ...[
                    bone(width: w, height: 34, r: 100),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              // Row-Platzhalter
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: lineColor),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        bone(width: 48, height: 48, r: 12),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bone(width: 140, height: 14, r: 4),
                              const SizedBox(height: 8),
                              bone(width: 90, height: 11, r: 4),
                            ],
                          ),
                        ),
                        bone(width: 56, height: 22, r: 100),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
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
