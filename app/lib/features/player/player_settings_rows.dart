import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';

/// Icon + label + switch row for the player settings panel.
class PlayerSettingsSwitchRow extends StatelessWidget {
  const PlayerSettingsSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final PlayerColors colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: AppIcons.sm, color: colors.controlFg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.controlFg,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: colors.progressPlayed,
              activeThumbColor: colors.controlFg,
              inactiveTrackColor: colors.controlFg.withValues(alpha: 0.18),
              inactiveThumbColor: colors.controlFgMuted,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + label + value/chevron row that navigates in-panel (no popup).
class PlayerSettingsValueNavRow extends StatelessWidget {
  const PlayerSettingsValueNavRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final PlayerColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '$label, $value',
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: AppIcons.sm, color: colors.controlFg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.controlFg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: colors.controlFgMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: colors.controlFgMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + label + value/chevron row that opens a [PopupMenuButton].
class PlayerSettingsValueMenuRow extends StatelessWidget {
  const PlayerSettingsValueMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.items,
    required this.onSelected,
    this.onOpened,
  });

  final IconData icon;
  final String label;
  final String value;
  final PlayerColors colors;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onOpened: onOpened,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      offset: const Offset(0, 8),
      child: Semantics(
        button: true,
        label: '$label, $value',
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: AppIcons.sm, color: colors.controlFg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.controlFg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: colors.controlFgMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: colors.controlFgMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
