import 'package:flutter/material.dart';

import '../../core/theme/player_colors.dart';
import '../../l10n/l10n.dart';
import 'player_settings_local_state.dart';
import 'player_settings_options_panel.dart';

/// Nested sleep-timer list — same chrome as quality (DESIGN.md nested list).
///
/// Options: Off · 15m · 30m · 60m · end of video. Local UI only (no engine yet).
class PlayerSettingsSleepPanel extends StatelessWidget {
  const PlayerSettingsSleepPanel({
    super.key,
    required this.colors,
    required this.sleepTimerMinutes,
    required this.onSelect,
    required this.onBack,
    this.onInteract,
  });

  final PlayerColors colors;
  final int? sleepTimerMinutes;
  final ValueChanged<int?> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onInteract;

  static const offId = 'off';
  static const endOfVideoId = 'end';

  static String idForMinutes(int? minutes) {
    if (minutes == null) return offId;
    if (minutes == PlayerSettingsLocalState.sleepTimerEndOfVideo) {
      return endOfVideoId;
    }
    return minutes.toString();
  }

  static int? minutesForId(String id) {
    if (id == offId || id.isEmpty) return null;
    if (id == endOfVideoId) {
      return PlayerSettingsLocalState.sleepTimerEndOfVideo;
    }
    return int.tryParse(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <PlayerSettingsOption>[
      PlayerSettingsOption(id: offId, label: l10n.playerSleepTimerOff),
      for (final m in PlayerSettingsLocalState.sleepTimerOptions)
        PlayerSettingsOption(
          id: m.toString(),
          label: playerSleepTimerValueLabel(m, l10n.playerSleepTimerOff),
        ),
      PlayerSettingsOption(
        id: endOfVideoId,
        label: l10n.playerSleepTimerEndOfVideo,
      ),
    ];

    return PlayerSettingsOptionsPanel(
      colors: colors,
      title: l10n.playerSleepTimer,
      backTooltip: l10n.back,
      options: options,
      selectedId: idForMinutes(sleepTimerMinutes),
      onBack: onBack,
      onInteract: onInteract,
      onSelect: (id) => onSelect(minutesForId(id)),
    );
  }
}
