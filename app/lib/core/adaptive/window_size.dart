import 'package:flutter/widgets.dart';

/// Window size classes — docs/ux/multi-platform.md §3.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
  large,
  extraLarge,
}

/// Resolve size class from a logical width (prefer content width when known).
WindowSizeClass windowSizeClassForWidth(double width) {
  if (width < 600) return WindowSizeClass.compact;
  if (width < 840) return WindowSizeClass.medium;
  if (width < 1200) return WindowSizeClass.expanded;
  if (width < 1600) return WindowSizeClass.large;
  return WindowSizeClass.extraLarge;
}

WindowSizeClass windowSizeClassOf(BuildContext context) {
  return windowSizeClassForWidth(MediaQuery.sizeOf(context).width);
}

/// Whether primary navigation should use a side rail (medium+).
bool usesNavigationRail(WindowSizeClass size) {
  return size != WindowSizeClass.compact;
}

/// Expanded rail shows icon + label; medium collapses to icon-only.
bool isRailExpanded(WindowSizeClass size) {
  return size.index >= WindowSizeClass.expanded.index;
}

/// Suggested video-card columns from **content** width — multi-platform §3.3.
int videoGridCrossAxisCount(double contentWidth) {
  if (contentWidth < 400) return 1;
  if (contentWidth < 700) return 2;
  if (contentWidth < 1000) return 3;
  if (contentWidth < 1300) return 4;
  if (contentWidth < 1600) return 5;
  return 6;
}
