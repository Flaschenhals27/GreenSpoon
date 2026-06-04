import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/gs_colors.dart';
import '../core/theme/gs_typography.dart';
import 'notifications/notification_scheduler.dart';
import 'pantry/presentation/add_item_dialog.dart';
import 'pantry/presentation/pantry_screen.dart';
import 'pantry/providers/pantry_providers.dart';
import 'profile/presentation/profile_screen.dart';
import 'recipes/presentation/recipes_screen.dart';
import 'scanner/presentation/grocery_photo_screen.dart';
import 'scanner/presentation/scanner_screen.dart';

/// Globaler ValueNotifier für Notification-Tap-Handler.
/// Indexe: 0 = Vorrat, 1 = Rezepte, 2 = Profil
final mainShellTabNotifier = ValueNotifier<int>(0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
    PantryScreen(),
    RecipesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mainShellTabNotifier.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mainShellTabNotifier.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    if (!mounted) return;
    setState(() => _index = mainShellTabNotifier.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pantryStreamProvider);
    }
  }

  void _openScanOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanOptionsSheet(
        isDark: isDark,
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
      ),
    );
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddItemDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hält die geplanten Ablauf-Erinnerungen aktuell: bei jeder Vorrats-
    // Änderung (Hinzufügen, Verwerten, MHD-Edit) und beim Resume neu planen.
    // [reschedule] ist selbst ein No-op, falls Benachrichtigungen aus sind.
    ref.listen(pantryStreamProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) NotificationScheduler.reschedule(items);
    });

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: isDark
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
          index: _index,
          children: _screens,
        ),
        bottomNavigationBar: _CustomNavBar(
          currentIndex: _index,
          isDark: isDark,
          onTabChanged: (i) {
            mainShellTabNotifier.value = i;
            setState(() => _index = i);
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
    required this.currentIndex,
    required this.isDark,
    required this.onTabChanged,
    required this.onScanTap,
    required this.onScanLongPress,
  });

  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onScanTap;
  final VoidCallback onScanLongPress;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: lineColor),
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
                    selected: currentIndex == 0,
                    isDark: isDark,
                    onTap: () => onTabChanged(0),
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
                    selected: currentIndex == 1,
                    isDark: isDark,
                    onTap: () => onTabChanged(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profil',
                    selected: currentIndex == 2,
                    isDark: isDark,
                    onTap: () => onTabChanged(2),
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
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final primaryColor = isDark ? GSColors.primaryMid : GSColors.primary;
    final activeColor = selected ? primaryColor : muteColor;

    return InkWell(
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
              color: selected ? inkColor : muteColor,
            ),
          ),
        ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

/// Auswahl beim Tippen auf den Scan-Button: einzeln scannen (Barcode/MHD)
/// oder den ganzen Einkauf abfotografieren (KI-Erkennung).
class _ScanOptionsSheet extends StatelessWidget {
  const _ScanOptionsSheet({
    required this.isDark,
    required this.onSingle,
    required this.onPhoto,
  });

  final bool isDark;
  final VoidCallback onSingle;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
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
                    color: muteColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('HINZUFÜGEN', style: GSTypography.label(color: muteColor)),
              const SizedBox(height: 12),
              _ScanOption(
                isDark: isDark,
                icon: Icons.qr_code_scanner,
                title: 'Einzeln scannen',
                subtitle: 'Barcode & MHD von verpackter Ware',
                onTap: onSingle,
              ),
              const SizedBox(height: 12),
              _ScanOption(
                isDark: isDark,
                icon: Icons.photo_camera_outlined,
                title: 'Einkauf fotografieren',
                subtitle: 'Obst, Gemüse & mehr auf einmal erkennen',
                badge: 'NEU',
                onTap: onPhoto,
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
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: lineColor),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: GSTypography.body(
                              color: inkColor,
                              size: 15.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2,),
                            decoration: BoxDecoration(
                              color: GSColors.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: GSTypography.body(
                                color: GSColors.accentDeep,
                                size: 10,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GSTypography.body(color: muteColor, size: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muteColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
