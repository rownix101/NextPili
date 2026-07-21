import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import 'player_settings_speed_widgets.dart';

/// One selectable row in a nested settings options list.
@immutable
class PlayerSettingsOption {
  const PlayerSettingsOption({
    required this.id,
    required this.label,
    this.badge,
  });

  final String id;
  final String label;
  final String? badge;
}

/// Shared nested option list (header + rows) used by quality / subtitle / sleep.
///
/// Same chrome as the quality sub-panel: back header, 44dp selectable rows.
class PlayerSettingsOptionsPanel extends StatelessWidget {
  const PlayerSettingsOptionsPanel({
    super.key,
    required this.colors,
    required this.title,
    required this.backTooltip,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    required this.onBack,
    this.onInteract,
    this.semanticLabel,
  });

  final PlayerColors colors;
  final String title;
  final String backTooltip;
  final List<PlayerSettingsOption> options;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onInteract;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Host may pass a max height (player chrome inset). A shrink-wrapped
          // list alone overflows; Flexible + shrinkWrap scrolls only when needed
          // and keeps short lists at natural height. Unbounded tests: plain list.
          final boundedHeight = constraints.hasBoundedHeight &&
              constraints.maxHeight < double.infinity;
          final list = ListView.builder(
            shrinkWrap: true,
            primary: false,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final selected = option.id == selectedId ||
                  (selectedId == null &&
                      index == 0 &&
                      options.isNotEmpty);
              return PlayerSettingsOptionRow(
                colors: colors,
                label: option.label,
                badge: option.badge,
                selected: selected,
                onTap: () {
                  onInteract?.call();
                  onSelect(option.id);
                },
              );
            },
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  0,
                ),
                child: PlayerSettingsSpeedHeader(
                  colors: colors,
                  title: title,
                  backTooltip: backTooltip,
                  onBack: () {
                    onInteract?.call();
                    onBack();
                  },
                ),
              ),
              if (boundedHeight) Flexible(child: list) else list,
            ],
          );
        },
      ),
    );
  }
}

/// Selectable option row (shared by quality / subtitle / sleep lists).
class PlayerSettingsOptionRow extends StatelessWidget {
  const PlayerSettingsOptionRow({
    super.key,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final PlayerColors colors;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? colors.controlFg : colors.controlFgMuted;
    final weight = selected ? FontWeight.w600 : FontWeight.w500;

    return Semantics(
      button: true,
      selected: selected,
      label: badge == null ? label : '$label $badge',
      child: Material(
        color: selected
            ? colors.progressPlayed.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: weight,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Text(
                      badge!,
                      style: TextStyle(
                        color: colors.controlFgMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
