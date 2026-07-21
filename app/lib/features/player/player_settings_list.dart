import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../l10n/l10n.dart';
import 'player_settings_local_state.dart';
import 'player_settings_rows.dart';

/// Main settings list body (switch rows + in-panel nav for value pickers).
class PlayerSettingsListBody extends StatelessWidget {
  const PlayerSettingsListBody({
    super.key,
    required this.colors,
    required this.local,
    required this.onLocalChanged,
    required this.qualityLabel,
    required this.speedLabel,
    required this.subtitleLabel,
    required this.onOpenSubtitle,
    required this.onOpenSleep,
    required this.onOpenSpeed,
    required this.onOpenQuality,
    this.onInteract,
  });

  final PlayerColors colors;
  final PlayerSettingsLocalState local;
  final ValueChanged<PlayerSettingsLocalState> onLocalChanged;
  final String qualityLabel;
  final String speedLabel;
  final String subtitleLabel;
  final VoidCallback onOpenSubtitle;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenQuality;
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sleepValue = playerSleepTimerValueLabel(
      local.sleepTimerMinutes,
      l10n.playerSleepTimerOff,
      endOfVideoLabel: l10n.playerSleepTimerEndOfVideo,
    );

    final rows = <Widget>[
      PlayerSettingsSwitchRow(
        icon: AppIcons.volume,
        label: l10n.playerStableVolume,
        value: local.stableVolume,
        colors: colors,
        onChanged: (v) {
          onInteract?.call();
          onLocalChanged(local.copyWith(stableVolume: v));
        },
      ),
      PlayerSettingsSwitchRow(
        icon: AppIcons.audioLines,
        label: l10n.playerVoiceBoost,
        value: local.voiceBoost,
        colors: colors,
        onChanged: (v) {
          onInteract?.call();
          onLocalChanged(local.copyWith(voiceBoost: v));
        },
      ),
      PlayerSettingsSwitchRow(
        icon: AppIcons.sparkles,
        label: l10n.playerAmbientMode,
        value: local.ambientMode,
        colors: colors,
        onChanged: (v) {
          onInteract?.call();
          onLocalChanged(local.copyWith(ambientMode: v));
        },
      ),
      PlayerSettingsValueNavRow(
        icon: AppIcons.captions,
        label: l10n.playerSubtitle,
        value: subtitleLabel,
        colors: colors,
        onTap: onOpenSubtitle,
      ),
      PlayerSettingsValueNavRow(
        icon: AppIcons.timer,
        label: l10n.playerSleepTimer,
        value: sleepValue,
        colors: colors,
        onTap: onOpenSleep,
      ),
      PlayerSettingsValueNavRow(
        icon: AppIcons.gauge,
        label: l10n.playerSpeed,
        value: speedLabel,
        colors: colors,
        onTap: onOpenSpeed,
      ),
      PlayerSettingsValueNavRow(
        icon: AppIcons.highQuality,
        label: l10n.playerQuality,
        value: qualityLabel,
        colors: colors,
        onTap: onOpenQuality,
      ),
    ];

    // shrinkWrap: intrinsic height when space allows; scrolls when the
    // PlayerPane host (top/bottom chrome gutters) is shorter than rows.
    return ListView(
      shrinkWrap: true,
      primary: false,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      children: rows,
    );
  }
}
