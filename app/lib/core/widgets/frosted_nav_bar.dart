import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import 'mica_surface.dart';

/// Edge-flush desktop compact tab bar: Mica tint + icon + label.
///
/// **Do not** use Flutter [BackdropFilter] for desktop wallpaper blur — the
/// engine cannot sample the compositor desktop. Real-time blur is requested
/// from the Linux compositor in `linux/runner/desktop_compositor_blur.cc`
/// (KWin X11 / Wayland). Win/macOS use DWM Mica / NSVisualEffectView.
///
/// docs/ux/design-system.md §2.5
class FrostedNavBar extends StatelessWidget {
  const FrostedNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.barHeight = 56,
  });

  final List<FrostedNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: MicaSurface(
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _FrostedNavTile(
                      item: items[i],
                      selected: i == selectedIndex,
                      colors: colors,
                      onTap: () => onSelect(i),
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

class FrostedNavItem {
  const FrostedNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _FrostedNavTile extends StatelessWidget {
  const _FrostedNavTile({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final FrostedNavItem item;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? colors.accent : colors.fgSecondary;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colors.fgPrimary.withValues(alpha: 0.04);
          }
          if (states.contains(WidgetState.pressed)) {
            return colors.accent.withValues(alpha: 0.10);
          }
          return null;
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: AppIcons.sm + 2, color: fg),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}
