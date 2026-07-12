import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/utils/display_name.dart';
import '../../../core/widgets/expiry_alert.dart';
import '../../../core/widgets/impact_ribbon.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/presentation/impact_screen.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../../shell/shell_providers.dart';
import '../domain/pantry_categories.dart';
import '../domain/pantry_filter.dart';
import '../domain/pantry_item.dart';
import '../providers/pantry_providers.dart';
import 'widgets/pantry_empty_state.dart';
import 'widgets/pantry_filter_pills.dart';
import 'widgets/pantry_row.dart';
import 'widgets/pantry_search_field.dart';
import 'widgets/pantry_skeleton.dart';

/// Vorrat-Tab: begrüßt den User, listet alle Items gruppiert nach Frische
/// und bietet Filter, Suche und den Ablauf-Alert.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _filter = kPantryFilterAll;

  // Suchfeld erscheint erst per Tap auf die Lupe.
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  // Nur Taps NEBEN Suchfeld/Lupe sollen die Suche schließen.
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

  /// Tap außerhalb: leeres Feld → Suche schließen; mit Begriff → nur
  /// Tastatur einklappen (sonst springt die Ergebnisliste weg).
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
    final asyncItems = ref.watch(pantryStreamProvider);
    final user = ref.watch(currentUserProvider);

    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    // Anzeigename: selbst gesetzt → aus der E-Mail abgeleitet → neutral.
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
          // Skeleton statt Spinner — kein Layout-Sprung beim Laden.
          loading: () => const PantrySkeleton(),
          error: (e, _) => _LoadError(error: e),
          data: (items) => _buildContent(items, initial, greeting),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<PantryItem> allItems,
    String initial,
    String greeting,
  ) {
    final tone = GSTone.of(context);

    final expiringSoon = allItems.where((p) => p.isExpiringSoon).toList();

    // Nur Filter anbieten, die auch Treffer hätten — tote Pills wären Ballast.
    final usedCategories = allItems.map((p) => p.category).toSet();
    final categories = [
      kPantryFilterAll,
      if (expiringSoon.isNotEmpty) kPantryFilterExpiringSoon,
      ...kPantryCategories.where(usedCategories.contains),
    ];
    // Verschwundener Filter (Kategorie leer) fällt auf „Alle" zurück.
    final filter =
        categories.contains(_filter) ? _filter : kPantryFilterAll;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = filterPantryItems(allItems, filter: filter, query: query);

    return Listener(
      // Listener statt GestureDetector: verliert nie die Gesten-Arena gegen Row-Taps.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: RefreshIndicator(
        color: GSColors.primary,
        backgroundColor: tone.surface,
        onRefresh: () async {
          ref.invalidate(pantryStreamProvider);
          // Aufs erste Event warten, damit der Indikator solange dreht wie geladen wird.
          await ref.read(pantryStreamProvider.future);
        },
        child: CustomScrollView(
          // Auch bei kurzem Inhalt ziehbar (Pull-to-Refresh).
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                greeting: greeting,
                initial: initial,
                searching: _searching,
                searchIconKey: _searchIconKey,
                onSearchTap: _toggleSearch,
                onAvatarTap: () =>
                    ref.read(shellTabProvider.notifier).open(ShellTab.profile),
              ),
            ),
            if (_searching)
              SliverToBoxAdapter(
                child: PantrySearchField(
                  key: _searchFieldKey,
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
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
                  onTap: () =>
                      setState(() => _filter = kPantryFilterExpiringSoon),
                ),
              ),
            SliverToBoxAdapter(
              child: PantryFilterPills(
                categories: categories,
                value: filter,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _filter = v);
                },
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PantryEmptyState(
                  searching: query.isNotEmpty,
                  // Scan-CTA nur bei wirklich leerem Vorrat (nicht bloß leerem Filter).
                  showScanCta: allItems.isEmpty && query.isEmpty,
                ),
              )
            else
              ..._buildGroups(filtered, filter),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(List<PantryItem> items, String filter) {
    // Bei aktivem Kategorie-Filter: nur eine Gruppe, kein Eyebrow nötig
    if (filter != kPantryFilterAll && filter != kPantryFilterExpiringSoon) {
      return [
        _itemSliver(items, padding: const EdgeInsets.fromLTRB(22, 4, 22, 0)),
      ];
    }

    // Bei Alle / Läuft bald ab: nach Frische gruppieren
    final groups = groupByFreshness(items);
    return [
      ..._group('BALD FÄLLIG', groups.soon),
      ..._group('INNERHALB VON 2 WOCHEN', groups.week),
      ..._group('LÄNGER HALTBAR', groups.later),
    ];
  }

  List<Widget> _group(String eyebrow, List<PantryItem> group) {
    if (group.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: _GroupHeader(eyebrow: eyebrow, count: group.length),
      ),
      _itemSliver(group, padding: const EdgeInsets.fromLTRB(22, 0, 22, 14)),
    ];
  }

  Widget _itemSliver(List<PantryItem> items, {required EdgeInsets padding}) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PantryRow(item: items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Fehlerzustand, wenn der Vorrats-Stream nicht lädt.
class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);
    return Center(
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
              style: GSTypography.headline(color: tone.ink, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Prüfe deine Verbindung und versuch es nochmal.\n($error)',
              textAlign: TextAlign.center,
              style: GSTypography.body(color: tone.inkMute, size: 12.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => ref.invalidate(pantryStreamProvider),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.initial,
    required this.searching,
    required this.searchIconKey,
    required this.onSearchTap,
    required this.onAvatarTap,
  });

  final String greeting;
  final String initial;
  final bool searching;

  /// Key für den „Tap daneben schließt"-Handler — die Lupe selbst zählt nicht als daneben.
  final GlobalKey searchIconKey;
  final VoidCallback onSearchTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

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
                  style: GSTypography.label(color: tone.inkMute),
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
                        color: tone.ink,
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
            style: GSTypography.headline(color: tone.ink, size: 34),
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
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(eyebrow, style: GSTypography.label(color: tone.inkMute)),
          Text(
            '$count',
            style: GSTypography.body(
              color: tone.inkMute,
              size: 12,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
