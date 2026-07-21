import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive/desktop_window.dart';
import '../../core/adaptive/form_factor.dart';
import '../../core/adaptive/window_size.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/frosted_nav_bar.dart';
import '../../core/widgets/glass/app_glass.dart';
import '../../core/widgets/mica_surface.dart';
import '../../l10n/l10n.dart';

class _NavDest {
  const _NavDest({
    required this.icon,
    required this.label,
    required this.location,
  });

  final IconData icon;
  final String label;
  final String location;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _paths = <String>[
    '/home',
    '/live',
    '/pgc',
    '/search',
    '/dynamics',
    '/library',
    '/settings',
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/pgc')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/dynamics')) return 4;
    if (location.startsWith('/library')) return 5;
    if (location.startsWith('/settings')) return 6;
    return 0;
  }

  void _goIndex(BuildContext context, int index) {
    if (index < 0 || index >= _paths.length) return;
    context.go(_paths[index]);
  }

  List<_NavDest> _destinations(AppLocalizations l10n) => [
        _NavDest(icon: AppIcons.home, label: l10n.navHome, location: '/home'),
        _NavDest(icon: AppIcons.live, label: l10n.navLive, location: '/live'),
        _NavDest(icon: AppIcons.movie, label: l10n.navPgc, location: '/pgc'),
        _NavDest(
          icon: AppIcons.search,
          label: l10n.navSearch,
          location: '/search',
        ),
        _NavDest(
          icon: AppIcons.dynamics,
          label: l10n.navDynamics,
          location: '/dynamics',
        ),
        _NavDest(
          icon: AppIcons.inbox,
          label: l10n.navLibrary,
          location: '/library',
        ),
        _NavDest(
          icon: AppIcons.settings,
          label: l10n.navSettings,
          location: '/settings',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);
    final sizeClass = windowSizeClassOf(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final dests = _destinations(l10n);
    final pierce = DesktopWindow.desktopPierceEnabled;

    // Desktop: search lives in chrome top bar (interaction §1.1 / §2.1).
    final railDests = dests.where((d) => d.location != '/search').toList();
    final railIndex = () {
      final loc = GoRouterState.of(context).uri.path;
      if (loc.startsWith('/search')) return -1;
      final i = railDests.indexWhere((d) => loc.startsWith(d.location));
      return i < 0 ? 0 : i;
    }();

    if (usesNavigationRail(sizeClass)) {
      return _DesktopShell(
        index: railIndex < 0 ? null : railIndex,
        dests: railDests,
        sizeClass: sizeClass,
        colors: colors,
        pierce: pierce,
        onSelect: (i) {
          if (i < 0 || i >= railDests.length) return;
          context.go(railDests[i].location);
        },
        onSearch: () => context.go('/search'),
        onAccount: () => context.push('/auth'),
        child: child,
      );
    }

    // Compact tab chrome:
    // - Mobile OS → floating Liquid Glass pill (design-system §2.5)
    // - Desktop narrow window → edge-flush Mica + icon/label (no frosted tray)
    if (isMobileOs) {
      return Scaffold(
        backgroundColor: colors.canvas,
        extendBody: true,
        body: child,
        bottomNavigationBar: MobileGlassTabBar(
          selectedIndex: index,
          onTabSelected: (i) => _goIndex(context, i),
          tabs: [
            for (final d in dests)
              GlassTab(
                icon: Icon(d.icon),
                label: d.label,
                semanticLabel: d.label,
                glowColor: colors.accent,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: pierce ? Colors.transparent : colors.canvas,
      extendBody: true,
      body: child,
      bottomNavigationBar: FrostedNavBar(
        selectedIndex: index,
        onSelect: (i) => _goIndex(context, i),
        items: [
          for (final d in dests)
            FrostedNavItem(icon: d.icon, label: d.label),
        ],
      ),
    );
  }
}

/// Opaque content tray — fills remaining space flush to rail / window edges.
///
/// No shell margin (no transparent pierce gaps) and no app-level window-edge
/// radius — WM owns outer corners.
class _OpaqueContentPanel extends StatelessWidget {
  const _OpaqueContentPanel({
    required this.colors,
    required this.child,
  });

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colors.canvas,
      child: child,
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.index,
    required this.dests,
    required this.sizeClass,
    required this.colors,
    required this.pierce,
    required this.onSelect,
    required this.onSearch,
    required this.onAccount,
    required this.child,
  });

  final int? index;
  final List<_NavDest> dests;
  final WindowSizeClass sizeClass;
  final AppColors colors;
  final bool pierce;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final VoidCallback onAccount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final expanded = isRailExpanded(sizeClass);
    final l10n = context.l10n;

    final chrome = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChromeTopBar(
          colors: colors,
          searchHint: l10n.searchHint,
          accountLabel: l10n.account,
          onSearch: onSearch,
          onAccount: onAccount,
        ),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      // Transparent only so native Mica / VE paint under the rail strip.
      backgroundColor: pierce ? Colors.transparent : colors.canvas,
      body: Row(
        children: [
          // Edge-flush Mica rail — no outer margin (no pierce voids).
          MicaSurface(
            width: expanded ? 88 : 72,
            borderRadius: BorderRadius.zero,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelect,
              labelType: expanded
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              backgroundColor: Colors.transparent,
              indicatorColor: colors.accent.withValues(alpha: 0.14),
              selectedIconTheme: IconThemeData(
                color: colors.accent,
                size: AppIcons.md,
              ),
              unselectedIconTheme: IconThemeData(
                color: colors.fgSecondary,
                size: AppIcons.md,
              ),
              selectedLabelTextStyle: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.accent),
              unselectedLabelTextStyle: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.fgSecondary),
              minWidth: expanded ? 80 : 64,
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: d.label,
                      child: Icon(d.icon),
                    ),
                    selectedIcon: Tooltip(
                      message: d.label,
                      child: Icon(d.icon),
                    ),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          Expanded(
            child: pierce
                ? _OpaqueContentPanel(colors: colors, child: chrome)
                : chrome,
          ),
        ],
      ),
    );
  }
}

/// Global chrome: visible search field + account — design-system §7.6 / interaction §2.1.
class _ChromeTopBar extends StatelessWidget {
  const _ChromeTopBar({
    required this.colors,
    required this.searchHint,
    required this.accountLabel,
    required this.onSearch,
    required this.onAccount,
  });

  final AppColors colors;
  final String searchHint;
  final String accountLabel;
  final VoidCallback onSearch;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Material(
                  color: colors.sunken.withValues(alpha: 0.85),
                  borderRadius: AppShapes.borderFull,
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: AppShapes.borderFull,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.search,
                            size: AppIcons.sm,
                            color: colors.fgMuted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              searchHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: colors.fgMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: accountLabel,
            child: Semantics(
              button: true,
              label: accountLabel,
              child: GlassIconButton(
                icon: Icon(
                  AppIcons.user,
                  size: AppIcons.sm,
                  color: colors.fgPrimary,
                ),
                onPressed: onAccount,
                size: 40,
                useOwnLayer: true,
                quality: GlassQuality.standard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
