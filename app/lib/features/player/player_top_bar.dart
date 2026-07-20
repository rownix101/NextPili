import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';

/// Top chrome row: optional back/title, danmaku toggle, mini, fullscreen.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.showTitle,
    required this.showBack,
    required this.onBack,
    required this.colors,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    this.onFullscreen,
    this.fullscreenExit = false,
    this.onMini,
  });

  final String title;
  final bool showTitle;
  final bool showBack;
  final VoidCallback? onBack;
  final PlayerColors colors;
  final bool danmakuOn;
  final VoidCallback onToggleDanmaku;
  final VoidCallback? onFullscreen;
  final bool fullscreenExit;
  final VoidCallback? onMini;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: colors.chromeGlass,
      child: Row(
        children: [
          if (showBack)
            NpIconButton(
              icon: AppIcons.arrowLeft,
              color: colors.controlFg,
              onPressed: onBack,
              tooltip: l10n.back,
            ),
          if (showTitle)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.controlFg, fontSize: 15),
              ),
            )
          else
            const Spacer(),
          NpIconButton(
            icon: AppIcons.danmaku,
            color: danmakuOn ? colors.controlFg : colors.controlFgMuted,
            onPressed: onToggleDanmaku,
            tooltip: danmakuOn ? l10n.playerDanmakuOff : l10n.playerDanmakuOn,
          ),
          if (onMini != null)
            NpIconButton(
              icon: AppIcons.pictureInPicture,
              color: colors.controlFg,
              onPressed: onMini,
              tooltip: l10n.playerMini,
            ),
          if (onFullscreen != null)
            NpIconButton(
              icon: fullscreenExit
                  ? AppIcons.fullscreenExit
                  : AppIcons.fullscreen,
              color: colors.controlFg,
              onPressed: onFullscreen,
              tooltip: fullscreenExit
                  ? l10n.playerFullscreenExit
                  : l10n.playerFullscreen,
            ),
        ],
      ),
    );
  }
}
