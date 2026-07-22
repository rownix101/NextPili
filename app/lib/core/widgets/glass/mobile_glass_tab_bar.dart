import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/spacing.dart';

/// Floating Liquid Glass bottom tab chrome for **mobile OS only**.
///
/// Aligns with design-system §2.5 (悬浮 GlassTabBar) and the material recipe
/// from `liquid_glass_widgets` Apple Music demo — chrome settings + jelly
/// indicator — while using NextPili semantic colors.
///
/// Expects **≤5** primary tabs (locked IA: 4 — home · dynamics · library · me).
/// Desktop compact stays on FrostedNavBar / Mica (not this widget).
///
/// Layout metrics are shared with the mini-player pill so overlays stack
/// above the tab chrome without hard-coded magic in feature code.
class MobileGlassTabBar extends StatelessWidget {
  const MobileGlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// Glass pill height inside [GlassTabBar.bottom].
  static const double barHeight = 64;

  /// Vertical pad around the glass pill (package layout).
  static const double barVerticalPadding = 12;

  /// Outer float inset (matches [SafeArea] minimum).
  static const double outerHPad = AppSpacing.md;
  static const double outerBottomPad = AppSpacing.sm;

  /// Now-playing glass pill (Apple Music demo height).
  static const double miniPillHeight = 50;

  /// Gap between mini pill and tab chrome.
  static const double miniPillGap = 8;

  /// Height of tab chrome above the home-indicator / screen bottom.
  static double tabChromeHeight(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final saBottom =
        safeBottom < outerBottomPad ? outerBottomPad : safeBottom;
    return saBottom + barVerticalPadding * 2 + barHeight;
  }

  /// [Positioned.bottom] for a mini play pill above the tab bar.
  static double miniPillBottom(BuildContext context) {
    return tabChromeHeight(context) + miniPillGap;
  }

  /// Chrome glass tuned like the Apple Music demo bar, stained with
  /// [AppColors.glassTintChrome] instead of hard-coded iOS greys.
  static LiquidGlassSettings chromeSettings(AppColors colors) {
    return LiquidGlassSettings(
      glassColor: colors.glassTintChrome,
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.01,
      lightIntensity: 0.5,
      ambientStrength: 0.08,
      refractiveIndex: 1.2,
      saturation: 1.2,
      specularSharpness: GlassSpecularSharpness.medium,
    );
  }

  /// Slightly denser pill glass (demo play-bar recipe).
  static LiquidGlassSettings pillSettings(AppColors colors) {
    return LiquidGlassSettings(
      glassColor: colors.glassTintChrome,
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.01,
      lightIntensity: 0.35,
      ambientStrength: 0.08,
      refractiveIndex: 1.2,
      saturation: 1.2,
      specularSharpness: GlassSpecularSharpness.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labelMuted = colors.fgSecondary.withValues(alpha: 0.9);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        outerHPad,
        0,
        outerHPad,
        outerBottomPad,
      ),
      child: GlassTabBar.bottom(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
        settings: chromeSettings(colors),
        selectedIconColor: colors.accent,
        unselectedIconColor: labelMuted,
        selectedLabelColor: colors.accent,
        unselectedLabelColor: labelMuted,
        // Selection pill — demo uses ~20% label; matches iOS 26 tab indicator.
        indicatorColor: colors.fgPrimary.withValues(alpha: 0.20),
        interactionGlowColor: colors.accent,
        quality: GlassQuality.standard,
        interactionBehavior: GlassInteractionBehavior.full,
        barHeight: barHeight,
        // Outer float margin is SafeArea; 4 primary tabs can breathe.
        horizontalPadding: 12,
        verticalPadding: barVerticalPadding,
        spacing: 8,
        iconSize: AppIcons.md,
        labelFontSize: 11,
        iconLabelSpacing: 2,
        magnification: 1.12,
      ),
    );
  }
}
