import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/gs_colors.dart';
import '../../core/theme/gs_tone.dart';
import '../../core/theme/gs_typography.dart';
import '../notifications/expiry_reminder_prompt.dart';
import '../notifications/notification_scheduler.dart';
import '../pantry/presentation/add_item_dialog.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../pantry/providers/pantry_providers.dart';
import '../profile/presentation/profile_screen.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../scanner/presentation/grocery_photo_screen.dart';
import '../scanner/presentation/scanner_screen.dart';
import '../widget/pantry_widget_updater.dart';
import 'shell_providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _screens = [
    PantryScreen(),
    RecipesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pantryStreamProvider);
    }
  }

  void _openScanOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanOptionsSheet(
        onSingle: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          );
        },
        onPhoto: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GroceryPhotoScreen()),
          );
        },
        onManual: () {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (_) => const AddItemDialog(),
          );
        },
      ),
    );
  }

  /// Einmaliger Erinnerungs-Prompt — ob/wann entscheidet [ExpiryReminderPrompt].
  Future<void> _maybeShowNotifPrompt() async {
    final items = ref.read(pantryStreamProvider).valueOrNull;
    if (items == null) return;

    final prompt = ref.read(expiryReminderPromptProvider);
    if (!await prompt.shouldAsk(items)) return;
    if (!mounted) return;

    final wants = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nichts mehr vergessen?'),
        content: const Text(
          'Dein Vorrat hat jetzt ein Haltbarkeitsdatum. Sollen wir dich '
          'kurz erinnern, bevor etwas abläuft? Eine Nachricht am Morgen, '
          'nur wenn wirklich etwas fällig ist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Später'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            // Endliche Mindestbreite — Theme-Default (volle Breite)
            // crasht in den unbegrenzten Dialog-Actions.
            style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
            child: const Text('Erinnere mich'),
          ),
        ],
      ),
    );

    if (wants != true || !mounted) return;
    final current = ref.read(pantryStreamProvider).valueOrNull;
    if (current != null) await prompt.enable(current);
  }

  void _openAddDialog() {
    // Kommt vom Long-Press auf den Scan-Button — kräftigeres Feedback,
    // damit klar ist: die Geste hat gegriffen.
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => const AddItemDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final tab = ref.watch(shellTabProvider);

    // Erinnerungen bei jeder Vorrats-Änderung neu planen (No-op wenn deaktiviert).
    ref.listen(pantryStreamProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) {
        NotificationScheduler.reschedule(items);
        // Homescreen-Widget mit denselben Daten aktuell halten.
        PantryWidgetUpdater.update(items);
        _maybeShowNotifPrompt();
      }
    });

    // Scan-Anfragen anderer Screens (z.B. CTA im leeren Vorrat).
    ref.listen(scanRequestProvider, (_, __) => _openScanOptions());

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: tone.isDark
              ? [
                  const Color(0xFF1E2A24),
                  const Color(0xFF14201A),
                ]
              : [
                  const Color(0xFFEBE1CD),
                  const Color(0xFFF5EDE0),
                ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: tab.index,
          children: _screens,
        ),
        bottomNavigationBar: _CustomNavBar(
          currentTab: tab,
          onTabChanged: (t) {
            if (t != tab) HapticFeedback.selectionClick();
            ref.read(shellTabProvider.notifier).open(t);
          },
          onScanTap: _openScanOptions,
          onScanLongPress: _openAddDialog,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _CustomNavBar extends StatelessWidget {
  const _CustomNavBar({
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
    required this.onScanLongPress,
  });

  final ShellTab currentTab;
  final ValueChanged<ShellTab> onTabChanged;
  final VoidCallback onScanTap;
  final VoidCallback onScanLongPress;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tone.surface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: tone.line),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.kitchen_outlined,
                    selectedIcon: Icons.kitchen,
                    label: 'Vorrat',
                    selected: currentTab == ShellTab.pantry,
                    onTap: () => onTabChanged(ShellTab.pantry),
                  ),
                ),
                // Zentraler Scan-Button (Position 2 — getauscht mit Rezepte)
                Expanded(
                  child: _ScanButton(
                    onTap: onScanTap,
                    onLongPress: onScanLongPress,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.restaurant_menu_outlined,
                    selectedIcon: Icons.restaurant_menu,
                    label: 'Rezepte',
                    selected: currentTab == ShellTab.recipes,
                    onTap: () => onTabChanged(ShellTab.recipes),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profil',
                    selected: currentTab == ShellTab.profile,
                    onTap: () => onTabChanged(ShellTab.profile),
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

// ─────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final activeColor = selected ? tone.primary : tone.inkMute;

    // `selected` macht den aktiven Tab für Screenreader erkennbar
    // („Vorrat, Tab, ausgewählt").
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: activeColor,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? tone.ink : tone.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.onTap,
    required this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Scannen',
        hint: 'Gedrückt halten, um manuell hinzuzufügen',
        child: Tooltip(
          message: 'Scannen — halten für manuelles Hinzufügen',
          // Semantik kommt vom umgebenden Semantics-Widget (Label + Hint),
          // sonst würde der Tooltip-Text doppelt vorgelesen.
          excludeFromSemantics: true,
          child: Material(
            color: GSColors.primary,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                width: 56,
                height: 48,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: GSColors.cream,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Scan-Auswahl: einzeln scannen, Einkauf fotografieren oder manuell eintragen.
class _ScanOptionsSheet extends StatelessWidget {
  const _ScanOptionsSheet({
    required this.onSingle,
    required this.onPhoto,
    required this.onManual,
  });

  final VoidCallback onSingle;
  final VoidCallback onPhoto;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tone.inkMute.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('HINZUFÜGEN', style: GSTypography.label(color: tone.inkMute)),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.qr_code_scanner,
                title: 'Einzeln scannen',
                subtitle: 'Barcode & MHD von verpackter Ware',
                onTap: onSingle,
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.photo_camera_outlined,
                title: 'Einkauf fotografieren',
                subtitle: 'Obst, Gemüse & mehr auf einmal erkennen',
                onTap: onPhoto,
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.edit_outlined,
                title: 'Selbst eintragen',
                subtitle: 'Ohne Kamera — Name, Menge & MHD eintippen',
                onTap: onManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: GSColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: GSColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: GSTypography.body(
                        color: tone.ink,
                        size: 15.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GSTypography.body(color: tone.inkMute, size: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tone.inkMute, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
