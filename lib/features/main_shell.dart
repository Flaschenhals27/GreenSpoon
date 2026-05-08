import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/gs_colors.dart';
import 'pantry/presentation/pantry_screen.dart';
import 'pantry/providers/pantry_providers.dart';
import 'profile/presentation/profile_screen.dart';
import 'recipes/presentation/recipes_screen.dart';

/// Globaler ValueNotifier, mit dem Notification-Tap-Handler die MainShell
/// zu einem bestimmten Tab navigieren kann.
final mainShellTabNotifier = ValueNotifier<int>(0);

/// Die Haupt-Hülle der App: Bottom-Tab-Bar mit drei Tabs
/// (Vorrat, Rezepte, Profil).
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
      // App kam wieder in den Vordergrund — Vorrat neu laden,
      // damit "läuft ab in X Tagen" korrekt ist.
      ref.invalidate(pantryStreamProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          mainShellTabNotifier.value = i;
          setState(() => _index = i);
        },
        backgroundColor: isDark ? GSColors.cardDark : GSColors.cardLight,
        indicatorColor: GSColors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen, color: GSColors.primary),
            label: 'Vorrat',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon:
                Icon(Icons.restaurant_menu, color: GSColors.primary),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: GSColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}