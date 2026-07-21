import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/theme/player_colors.dart';
import '../../l10n/l10n.dart';
import 'player_settings_options_panel.dart';

/// Nested quality list inside the settings plate (shared options list chrome).
///
/// Vertical resolution rows with optional HD badge for 1080p+.
class PlayerSettingsQualityPanel extends StatelessWidget {
  const PlayerSettingsQualityPanel({
    super.key,
    required this.colors,
    required this.qualities,
    required this.currentId,
    required this.onQuality,
    required this.onBack,
    this.onInteract,
  });

  final PlayerColors colors;
  final List<StreamDto> qualities;
  final String? currentId;
  final ValueChanged<StreamDto> onQuality;
  final VoidCallback onBack;
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      for (final q in qualities)
        PlayerSettingsOption(
          id: q.id,
          label: q.qualityLabel,
          badge: playerQualityHdBadge(q),
        ),
    ];

    return PlayerSettingsOptionsPanel(
      colors: colors,
      title: l10n.playerQuality,
      backTooltip: l10n.back,
      options: options,
      selectedId: currentId,
      onBack: onBack,
      onInteract: onInteract,
      onSelect: (id) {
        for (final q in qualities) {
          if (q.id == id) {
            onQuality(q);
            return;
          }
        }
        if (qualities.isNotEmpty) onQuality(qualities.first);
      },
    );
  }
}

/// Small secondary badge for HD-class streams (qn ≥ 80 / 1080p ladder).
String? playerQualityHdBadge(StreamDto stream) {
  final qn = stream.qn;
  if (qn != null && qn >= 80) return 'HD';
  final h = stream.height;
  if (h != null && h >= 1080) return 'HD';
  return null;
}
