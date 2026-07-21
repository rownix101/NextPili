import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/theme/player_colors.dart';
import '../../l10n/l10n.dart';
import 'player_settings_options_panel.dart';

/// Nested subtitle track list — same chrome as quality (DESIGN.md nested list).
class PlayerSettingsSubtitlePanel extends StatelessWidget {
  const PlayerSettingsSubtitlePanel({
    super.key,
    required this.colors,
    required this.tracks,
    required this.currentId,
    required this.onSubtitle,
    required this.onBack,
    this.onInteract,
  });

  final PlayerColors colors;
  final List<SubtitleTrackDto> tracks;
  final String? currentId;
  final ValueChanged<SubtitleTrackDto?> onSubtitle;
  final VoidCallback onBack;
  final VoidCallback? onInteract;

  /// Sentinel id for “off” in the shared options list.
  static const offId = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <PlayerSettingsOption>[
      PlayerSettingsOption(id: offId, label: l10n.playerSubtitleOff),
      for (final t in tracks)
        PlayerSettingsOption(id: t.id, label: t.label),
    ];

    return PlayerSettingsOptionsPanel(
      colors: colors,
      title: l10n.playerSubtitle,
      backTooltip: l10n.back,
      options: options,
      selectedId: currentId ?? offId,
      onBack: onBack,
      onInteract: onInteract,
      onSelect: (id) {
        if (id == offId || id.isEmpty) {
          onSubtitle(null);
          return;
        }
        for (final t in tracks) {
          if (t.id == id) {
            onSubtitle(t);
            return;
          }
        }
        onSubtitle(tracks.isEmpty ? null : tracks.first);
      },
    );
  }
}
