import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../l10n/l10n.dart';
import 'player_adapter.dart';
import 'player_bottom_chrome.dart';
import 'player_settings_speed.dart';
import 'player_settings_speed_widgets.dart';

export 'player_settings_speed.dart';

/// Nested playback-speed controls inside the settings plate (DESIGN.md §5.1).
///
/// Rate changes go **only** through [onSpeed]. Options default to
/// [MediaKitPlayerAdapter.speedOptions].
class PlayerSettingsSpeedPanel extends StatelessWidget {
  const PlayerSettingsSpeedPanel({
    super.key,
    required this.colors,
    required this.currentSpeed,
    required this.onSpeed,
    required this.onBack,
    this.speedOptions = MediaKitPlayerAdapter.speedOptions,
    this.onInteract,
  });

  final PlayerColors colors;
  final double currentSpeed;
  final ValueChanged<double> onSpeed;
  final VoidCallback onBack;
  final List<double> speedOptions;
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = speedOptions;
    final index = playerSpeedOptionIndex(currentSpeed, options);
    final rate = options.isEmpty ? currentSpeed : options[index];
    final label = playerSpeedLabel(rate);
    final canDec = index > 0;
    final canInc = index < options.length - 1;
    final maxIndex =
        options.length <= 1 ? 0.0 : (options.length - 1).toDouble();

    return Semantics(
      container: true,
      label: l10n.playerSpeed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayerSettingsSpeedHeader(
              colors: colors,
              title: l10n.playerSpeed,
              backTooltip: l10n.back,
              onBack: () {
                onInteract?.call();
                onBack();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              label: label,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.controlFg,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                PlayerSettingsSpeedStepButton(
                  icon: AppIcons.minus,
                  colors: colors,
                  tooltip: l10n.playerSpeedDecrease,
                  enabled: canDec,
                  onPressed: () {
                    final next = playerSpeedStepRate(
                      rate,
                      options,
                      delta: -1,
                    );
                    if (next == null) return;
                    onInteract?.call();
                    onSpeed(next);
                  },
                ),
                Expanded(
                  child: MergeSemantics(
                    child: Semantics(
                      label: l10n.playerSpeedSlider,
                      value: label,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: colors.controlFg,
                          inactiveTrackColor:
                              colors.controlFg.withValues(alpha: 0.28),
                          thumbColor: colors.controlFg,
                          overlayColor:
                              colors.controlFg.withValues(alpha: 0.12),
                        ),
                        child: Slider(
                          value: index.toDouble().clamp(0.0, maxIndex),
                          min: 0,
                          max: maxIndex,
                          divisions: options.length <= 1
                              ? null
                              : options.length - 1,
                          label: label,
                          semanticFormatterCallback: (_) => label,
                          onChanged: options.length <= 1
                              ? null
                              : (v) {
                                  final i = v.round().clamp(
                                        0,
                                        options.length - 1,
                                      );
                                  final next = options[i];
                                  if (next == rate) return;
                                  onInteract?.call();
                                  onSpeed(next);
                                },
                        ),
                      ),
                    ),
                  ),
                ),
                PlayerSettingsSpeedStepButton(
                  icon: AppIcons.plus,
                  colors: colors,
                  tooltip: l10n.playerSpeedIncrease,
                  enabled: canInc,
                  onPressed: () {
                    final next = playerSpeedStepRate(
                      rate,
                      options,
                      delta: 1,
                    );
                    if (next == null) return;
                    onInteract?.call();
                    onSpeed(next);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PlayerSettingsSpeedChips(
              colors: colors,
              options: options,
              currentIndex: index,
              onSelect: (r) {
                onInteract?.call();
                onSpeed(r);
              },
            ),
          ],
        ),
      ),
    );
  }
}
