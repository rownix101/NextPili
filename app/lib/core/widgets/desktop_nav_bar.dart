import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import 'chrome_surface.dart';

/// Edge-flush desktop compact tab bar: opaque icon + label chrome.
class DesktopNavBar extends StatelessWidget {
  const DesktopNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.barHeight = 56,
  });

  final List<DesktopNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: ChromeSurface(
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _DesktopNavTile(
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

class DesktopNavItem {
  const DesktopNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final DesktopNavItem item;
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
