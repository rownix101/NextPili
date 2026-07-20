import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/settings')) return 1;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final colors = AppColors.of(context);

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
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(AppIcons.home),
                  selectedIcon: Icon(AppIcons.home),
                  label: Text('首页'),
                ),
                NavigationRailDestination(
                  icon: Icon(AppIcons.settings),
                  selectedIcon: Icon(AppIcons.settings),
                  label: Text('设置'),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settings),
            selectedIcon: Icon(AppIcons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
