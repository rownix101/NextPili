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

  /// Desktop rail / compact bar (search lives in chrome top bar).
  List<_NavDest> _desktopDestinations(AppLocalizations l10n) => [
        _NavDest(icon: AppIcons.home, label: l10n.navHome, location: '/home'),
        _NavDest(icon: AppIcons.live, label: l10n.navLive, location: '/live'),
        _NavDest(icon: AppIcons.movie, label: l10n.navPgc, location: '/pgc'),
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

  /// Mobile bottom bar — 4 primaries (multi-platform §4.1 / interaction §1.1).
  /// Search is chrome; live/pgc are home secondary; settings under Me.
  List<_NavDest> _mobileDestinations(AppLocalizations l10n) => [
        _NavDest(icon: AppIcons.home, label: l10n.navHome, location: '/home'),
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
        _NavDest(icon: AppIcons.user, label: l10n.navMe, location: '/me'),
      ];

  int _mobileIndexFor(String path) {
    if (path.startsWith('/dynamics')) return 1;
    if (path.startsWith('/library')) return 2;
    if (path.startsWith('/me') ||
        path.startsWith('/settings') ||
        path.startsWith('/auth')) {
      return 3;
    }
    // /home, /live, /pgc, /search → home family
    return 0;
  }

  int _desktopIndexFor(List<_NavDest> dests, String path) {
    if (path.startsWith('/search')) return -1;
    final i = dests.indexWhere((d) => path.startsWith(d.location));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final sizeClass = windowSizeClassOf(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final pierce = DesktopWindow.desktopPierceEnabled;

    if (usesNavigationRail(sizeClass)) {
      final dests = _desktopDestinations(l10n);
      final index = _desktopIndexFor(dests, path);
      return _DesktopShell(
        index: index < 0 ? null : index,
        dests: dests,
        sizeClass: sizeClass,
        colors: colors,
        pierce: pierce,
        onSelect: (i) {
          if (i < 0 || i >= dests.length) return;
          context.go(dests[i].location);
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
      final dests = _mobileDestinations(l10n);
      final index = _mobileIndexFor(path);
      return Scaffold(
        backgroundColor: colors.canvas,
        extendBody: true,
        body: child,
        bottomNavigationBar: MobileGlassTabBar(
          selectedIndex: index,
          onTabSelected: (i) {
            if (i < 0 || i >= dests.length) return;
            context.go(dests[i].location);
          },
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

    final dests = _desktopDestinations(l10n);
    final index = _desktopIndexFor(dests, path);
    final barIndex = index < 0 ? 0 : index;
    return Scaffold(
      backgroundColor: pierce ? Colors.transparent : colors.canvas,
      extendBody: true,
      body: child,
      bottomNavigationBar: FrostedNavBar(
        selectedIndex: barIndex,
        onSelect: (i) {
          if (i < 0 || i >= dests.length) return;
          context.go(dests[i].location);
        },
        items: [
          for (final d in dests) FrostedNavItem(icon: d.icon, label: d.label),
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
