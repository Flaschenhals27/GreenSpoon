import 'package:flutter/material.dart';

import '../core/theme/gs_colors.dart';
import 'pantry/presentation/pantry_screen.dart';
import 'recipes/presentation/recipes_screen.dart';

/// Die Haupt-Hülle der App: Bottom-Tab-Bar mit zwei Tabs (Vorrat, Rezepte).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    PantryScreen(),
    RecipesScreen(),
  ];

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
        onDestinationSelected: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }
}