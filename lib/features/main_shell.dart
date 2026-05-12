import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/gs_colors.dart';
import 'pantry/presentation/add_item_dialog.dart';
import 'pantry/presentation/pantry_screen.dart';
import 'pantry/providers/pantry_providers.dart';
import 'profile/presentation/profile_screen.dart';
import 'recipes/presentation/recipes_screen.dart';
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

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
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
          onScanTap: _openScanner,
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