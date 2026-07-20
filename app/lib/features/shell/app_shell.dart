import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/pgc')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/dynamics')) return 4;
    if (location.startsWith('/library')) return 5;
    if (location.startsWith('/settings')) return 6;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/live');
      case 2:
        context.go('/pgc');
      case 3:
        context.go('/search');
      case 4:
        context.go('/dynamics');
      case 5:
        context.go('/library');
      case 6:
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

    final destinationsRail = [
      NavigationRailDestination(
        icon: const Icon(AppIcons.home),
        selectedIcon: const Icon(AppIcons.home),
        label: Text(l10n.navHome),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.live),
        selectedIcon: const Icon(AppIcons.live),
        label: Text(l10n.navLive),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.movie),
        selectedIcon: const Icon(AppIcons.movie),
        label: Text(l10n.navPgc),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.search),
        selectedIcon: const Icon(AppIcons.search),
        label: Text(l10n.navSearch),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.dynamics),
        selectedIcon: const Icon(AppIcons.dynamics),
        label: Text(l10n.navDynamics),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.inbox),
        selectedIcon: const Icon(AppIcons.inbox),
        label: Text(l10n.navLibrary),
      ),
      NavigationRailDestination(
        icon: const Icon(AppIcons.settings),
        selectedIcon: const Icon(AppIcons.settings),
        label: Text(l10n.navSettings),
      ),
    ];

    final destinationsBar = [
      NavigationDestination(
        icon: const Icon(AppIcons.home),
        selectedIcon: const Icon(AppIcons.home),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.live),
        selectedIcon: const Icon(AppIcons.live),
        label: l10n.navLive,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.movie),
        selectedIcon: const Icon(AppIcons.movie),
        label: l10n.navPgc,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.search),
        selectedIcon: const Icon(AppIcons.search),
        label: l10n.navSearch,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.dynamics),
        selectedIcon: const Icon(AppIcons.dynamics),
        label: l10n.navDynamics,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.inbox),
        selectedIcon: const Icon(AppIcons.inbox),
        label: l10n.navLibrary,
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.settings),
        selectedIcon: const Icon(AppIcons.settings),
        label: l10n.navSettings,
      ),
    ];

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
              destinations: destinationsRail,
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
        destinations: destinationsBar,
      ),
    );
  }
}
