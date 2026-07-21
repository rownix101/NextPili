import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import 'player_bottom_chrome.dart';

/// Header row for the nested speed sub-panel (back + title).
class PlayerSettingsSpeedHeader extends StatelessWidget {
  const PlayerSettingsSpeedHeader({
    super.key,
    required this.colors,
    required this.title,
    required this.backTooltip,
    required this.onBack,
  });

  final PlayerColors colors;
  final String title;
  final String backTooltip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: backTooltip,
            icon: Icon(
              AppIcons.chevronLeft,
              size: AppIcons.sm,
              color: colors.controlFg,
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.controlFg,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Balance the leading 40 so the title stays optically centered.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Circular − / + control used around the discrete speed slider.
class PlayerSettingsSpeedStepButton extends StatelessWidget {
  const PlayerSettingsSpeedStepButton({
    super.key,
    required this.icon,
    required this.colors,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final PlayerColors colors;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = enabled
        ? colors.controlFg
        : colors.controlFg.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: colors.controlFg.withValues(alpha: enabled ? 0.12 : 0.06),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick-select chips: single equal-width row (DESIGN.md §5.1).
///
/// Seven canonical options + 4dp gaps fit in panel content width
/// (280 − 16 horizontal padding) without wrap or overflow.
class PlayerSettingsSpeedChips extends StatelessWidget {
  const PlayerSettingsSpeedChips({
    super.key,
    required this.colors,
    required this.options,
    required this.currentIndex,
    required this.onSelect,
  });

  final PlayerColors colors;
  final List<double> options;
  final int currentIndex;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _SpeedChip(
              colors: colors,
              label: playerSpeedLabel(options[i]),
              selected: i == currentIndex,
              onTap: () => onSelect(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PlayerColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? colors.progressPlayed.withValues(alpha: 0.28)
        : colors.controlFg.withValues(alpha: 0.10);
    final fg = selected ? colors.controlFg : colors.controlFgMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: AppShapes.borderSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShapes.borderSm,
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
