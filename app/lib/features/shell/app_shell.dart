import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/search');
      case 2:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    if (wide) {
      return Scaffold(
        backgroundColor: colors.canvas,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _onDestinationSelected(context, i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: colors.elevated.withValues(alpha: 0.55),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(AppIcons.home),
                  selectedIcon: const Icon(AppIcons.home),
                  label: Text(l10n.navHome),
                ),
                NavigationRailDestination(
                  icon: const Icon(AppIcons.search),
                  selectedIcon: const Icon(AppIcons.search),
                  label: Text(l10n.navSearch),
                ),
                NavigationRailDestination(
                  icon: const Icon(AppIcons.settings),
                  selectedIcon: const Icon(AppIcons.settings),
                  label: Text(l10n.navSettings),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: colors.borderSubtle),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.home),
            selectedIcon: const Icon(AppIcons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.search),
            selectedIcon: const Icon(AppIcons.search),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.settings),
            selectedIcon: const Icon(AppIcons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
