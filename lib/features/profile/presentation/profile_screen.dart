import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/utils/display_name.dart';
import '../../auth/providers/auth_providers.dart';
import '../../recipes/presentation/saved_recipes_screen.dart';
import '../../recipes/providers/saved_recipe_providers.dart';
import '../providers/avatar_providers.dart';
import '../providers/dietary_prefs_providers.dart';
import '../providers/profile_providers.dart';
import 'dietary_prefs_sheet.dart';
import 'profile_avatar.dart';
import 'widgets/impact_hero_card.dart';
import 'widgets/name_edit_dialog.dart';
import 'widgets/reminder_settings_card.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/theme_section.dart';

/// Profil-Tab: Nutzerdaten, Impact-Statistiken und alle Einstellungen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  /// Dialog zum Ändern des Anzeigenamens. Der Name landet in den
  /// Supabase-User-Metadaten; das `userUpdated`-Event aktualisiert
  /// [currentUserProvider] und damit Begrüßung + Profil automatisch.
  Future<void> _editDisplayName(String current) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => NameEditDialog(initial: current),
    );
    if (saved == null || saved.trim() == current) return;
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.trim().isEmpty
                  ? 'Name zurückgesetzt'
                  : 'Alles klar, ${saved.trim()}!',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name konnte nicht gespeichert werden.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich abmelden?'),
        content: const Text('Du wirst zum Login-Screen zurückgeleitet.'),
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
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  String _formatMonthYear(DateTime d) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(userStatsProvider);

    final email = user?.email ?? 'unbekannt';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    // Anzeigename: selbst gesetzt → sonst aus der E-Mail abgeleitet.
    // Bearbeitbar direkt am Namen (Stift daneben), keine eigene Kachel.
    final rawName = user?.userMetadata?['display_name'];
    final customName = rawName is String ? rawName.trim() : '';
    final headlineName = customName.isNotEmpty
        ? customName
        : (deriveDisplayNameFromEmail(email) ?? email.split('@').first);
    final memberSince = user?.createdAt != null
        ? _formatMonthYear(DateTime.parse(user!.createdAt))
        : '—';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        // Ripple deaktivieren — der rechteckige Ink-Splash würde sonst
        // über die runden Kartenecken hinausleuchten.
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _header(tone, headlineName),
              _identityRow(tone, initial, email, memberSince),

              // Großer Impact-Block
              stats.maybeWhen(
                data: (s) => ImpactHeroCard(stats: s),
                orElse: () => const SizedBox.shrink(),
              ),

              // Stats
              stats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Stats konnten nicht geladen werden.',
                    style: GSTypography.body(color: tone.inkMute, size: 13),
                  ),
                ),
                data: (s) => SettingsCard(
                  children: [
                    StatRow(label: 'Im Vorrat', value: '${s.inPantry}'),
                    const SettingsDivider(),
                    StatRow(
                      label: 'Diese Woche verwertet',
                      value: '${s.cookedThisWeek}',
                    ),
                    const SettingsDivider(),
                    StatRow(
                      label: 'Verwertet gesamt',
                      value: '${s.consumedTotal}',
                    ),
                    const SettingsDivider(),
                    StatRow(
                      label: 'Weggeworfen gesamt',
                      value: '${s.wastedTotal}',
                    ),
                    const SettingsDivider(),
                    StatRow(
                      label: 'Auf den letzten Drücker',
                      value: '${s.buzzerSaves}',
                    ),
                    const SettingsDivider(),
                    StatRow(
                      label: 'Eingespart (Schätzung)',
                      value: '${s.eurSaved.toStringAsFixed(0)} €',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SectionLabel(text: 'MEINE REZEPTE'),
              _savedRecipesCard(),

              const SizedBox(height: 24),

              const SectionLabel(text: 'ERNÄHRUNG'),
              _dietaryPrefsCard(),

              const SizedBox(height: 24),

              const SectionLabel(text: 'DARSTELLUNG'),
              const ThemeSection(),

              const SizedBox(height: 24),

              const SectionLabel(text: 'BENACHRICHTIGUNGEN'),
              const ReminderSettingsCard(),

              const SizedBox(height: 24),

              const SectionLabel(text: 'KONTO'),
              _logoutCard(tone),

              const SizedBox(height: 20),
              // Kleiner Abschieds-Gruß unterm Einstellungs-Screen —
              // Löffel-Wortspiel auf „Frisch gewagt ist halb gewonnen".
              Center(
                child: Text(
                  '„Gut gelöffelt ist halb gerettet." 🥄🌿',
                  textAlign: TextAlign.center,
                  style: GSTypography.italicCaption(color: tone.inkMute)
                      .copyWith(fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _appVersion.isEmpty
                      ? 'GreenSpoon'
                      : 'GreenSpoon · Version $_appVersion (Beta)',
                  style: GSTypography.italicCaption(color: tone.inkMute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(GSTone tone, String headlineName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROFIL', style: GSTypography.label(color: tone.inkMute)),
          const SizedBox(height: 8),
          // Name + Stift direkt daneben — bearbeiten, wo man liest.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  headlineName,
                  overflow: TextOverflow.ellipsis,
                  style: GSTypography.headline(color: tone.ink, size: 34),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Namen ändern',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _editDisplayName(headlineName),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      color: tone.inkMute,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityRow(
    GSTone tone,
    String initial,
    String email,
    String memberSince,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final hasAvatar = ref.read(avatarProvider).valueOrNull != null;
              showAvatarPicker(context, ref, hasAvatar: hasAvatar);
            },
            child: ProfileAvatar(
              initial: initial,
              size: 64,
              showEditBadge: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: GSTypography.body(
                    color: tone.ink,
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Mitglied seit $memberSince',
                  style: GSTypography.body(color: tone.inkMute, size: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedRecipesCard() {
    return Consumer(
      builder: (context, ref, _) {
        final saved = ref.watch(savedRecipesProvider);
        final count = saved.maybeWhen(
          data: (r) => r.length,
          orElse: () => null,
        );
        final subtitle = count == null
            ? 'Deine Sammlung'
            : count == 0
                ? 'Noch nichts gespeichert'
                : '$count gespeichert';
        return SettingsCard(
          children: [
            SettingsNavTile(
              icon: Icons.bookmark_outline,
              title: 'Gespeicherte Rezepte',
              subtitle: subtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dietaryPrefsCard() {
    return Consumer(
      builder: (context, ref, _) {
        final prefs = ref.watch(dietaryPrefsProvider);
        final tags = prefs.maybeWhen(
          data: (t) => t,
          orElse: () => const <String>[],
        );
        return SettingsCard(
          children: [
            SettingsNavTile(
              icon: Icons.restaurant_outlined,
              title: 'Ernährungsweise',
              subtitle: tags.isEmpty
                  ? 'Keine Vorgaben — alles ist ok'
                  : tags.join(' · '),
              onTap: () async {
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DietaryPrefsSheet(initial: tags),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _logoutCard(GSTone tone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Material(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _confirmLogout,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.logout, color: GSColors.accent, size: 22),
                const SizedBox(width: 14),
                Text(
                  'Abmelden',
                  style: GSTypography.body(
                    color: GSColors.accent,
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
