import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'player_adapter.dart';

/// Bottom chrome: danmaku composer, seek bar, transport + stream menus.
class PlayerBottomChrome extends StatelessWidget {
  const PlayerBottomChrome({
    super.key,
    required this.adapter,
    required this.colors,
    required this.onQuality,
    required this.onSpeed,
    required this.onSubtitle,
    required this.danmakuOn,
    required this.dmComposer,
    required this.sendingDm,
    required this.onSendDanmaku,
    required this.onDmFocus,
    this.onFullscreen,
    this.fullscreenExit = false,
    this.onHoldChrome,
    this.onInteract,
  });

  final MediaKitPlayerAdapter adapter;
  final PlayerColors colors;
  final ValueChanged<StreamDto> onQuality;
  final ValueChanged<double> onSpeed;
  final ValueChanged<SubtitleTrackDto?> onSubtitle;
  final bool danmakuOn;
  final TextEditingController dmComposer;
  final bool sendingDm;
  final VoidCallback onSendDanmaku;
  final ValueChanged<bool> onDmFocus;
  final VoidCallback? onFullscreen;
  final bool fullscreenExit;
  final ValueChanged<bool>? onHoldChrome;
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<Duration>(
      stream: adapter.player.stream.position,
      initialData: adapter.player.state.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: adapter.player.stream.duration,
          initialData: adapter.player.state.duration,
          builder: (context, durSnap) {
            return StreamBuilder<bool>(
              stream: adapter.player.stream.playing,
              initialData: adapter.player.state.playing,
              builder: (context, playSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = durSnap.data ?? Duration.zero;
                final playing = playSnap.data ?? false;
                final maxMs =
                    dur.inMilliseconds.toDouble().clamp(1.0, 1e12).toDouble();
                final value =
                    pos.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();

                final qualities = adapter.qualityOptions;
                final subs = adapter.subtitleOptions;
                final currentQ = adapter.currentVideo;
                final currentSub = adapter.currentSubtitle;
                final rate = adapter.rate;

                return Material(
                  color: colors.chromeGlass,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (danmakuOn)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: dmComposer,
                                    enabled: !sendingDm,
                                    maxLines: 1,
                                    maxLength: 100,
                                    style: TextStyle(
                                      color: colors.controlFg,
                                      fontSize: 13,
                                    ),
                                    cursorColor: colors.controlFg,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      counterText: '',
                                      hintText: l10n.playerDanmakuHint,
                                      hintStyle: TextStyle(
                                        color: colors.controlFgMuted,
                                        fontSize: 13,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      filled: true,
                                      fillColor: colors.controlFg
                                          .withValues(alpha: 0.08),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.send,
                                    onTap: () => onDmFocus(true),
                                    onTapOutside: (_) => onDmFocus(false),
                                    onSubmitted: (_) => onSendDanmaku(),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed:
                                      sendingDm ? null : onSendDanmaku,
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.controlFg,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: sendingDm
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.controlFg,
                                          ),
                                        )
                                      : Text(l10n.playerDanmakuSend),
                                ),
                              ],
                            ),
                          ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: colors.progressPlayed,
                            inactiveTrackColor: colors.progressTrack,
                            thumbColor: colors.progressPlayed,
                          ),
                          child: Slider(
                            value: value,
                            max: maxMs,
                            onChangeStart: (_) => onHoldChrome?.call(true),
                            onChanged: (v) {
                              adapter.seek(Duration(milliseconds: v.round()));
                            },
                            onChangeEnd: (_) => onHoldChrome?.call(false),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final controls = Row(
                              children: [
                                NpIconButton(
                                  icon:
                                      playing ? AppIcons.pause : AppIcons.play,
                                  color: colors.controlFg,
                                  onPressed: () {
                                    onInteract?.call();
                                    if (playing) {
                                      adapter.pause();
                                    } else {
                                      adapter.play();
                                    }
                                  },
                                  tooltip: playing ? l10n.pause : l10n.play,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${formatPlayerDuration(pos)} / ${formatPlayerDuration(dur)}',
                                  style: TextStyle(
                                    color: colors.controlFgMuted,
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (qualities.isNotEmpty)
                                  PlayerTextMenuButton(
                                    label: currentQ?.qualityLabel ??
                                        l10n.playerQuality,
                                    tooltip: l10n.playerQuality,
                                    colors: colors,
                                    onOpened: () => onHoldChrome?.call(true),
                                    onClosed: () => onHoldChrome?.call(false),
                                    items: [
                                      for (final q in qualities)
                                        PopupMenuItem(
                                          value: q.id,
                                          child: Text(q.qualityLabel),
                                        ),
                                    ],
                                    onSelected: (id) {
                                      final q = qualities.firstWhere(
                                        (e) => e.id == id,
                                        orElse: () => qualities.first,
                                      );
                                      onQuality(q);
                                    },
                                  ),
                                PlayerTextMenuButton(
                                  label: playerSpeedLabel(rate),
                                  tooltip: l10n.playerSpeed,
                                  colors: colors,
                                  onOpened: () => onHoldChrome?.call(true),
                                  onClosed: () => onHoldChrome?.call(false),
                                  items: [
                                    for (final r
                                        in MediaKitPlayerAdapter.speedOptions)
                                      PopupMenuItem(
                                        value: r.toString(),
                                        child: Text(playerSpeedLabel(r)),
                                      ),
                                  ],
                                  onSelected: (v) {
                                    final r = double.tryParse(v);
                                    if (r != null) onSpeed(r);
                                  },
                                ),
                                if (subs.isNotEmpty)
                                  PlayerTextMenuButton(
                                    label: currentSub?.label ??
                                        l10n.playerSubtitleOff,
                                    tooltip: l10n.playerSubtitle,
                                    colors: colors,
                                    onOpened: () => onHoldChrome?.call(true),
                                    onClosed: () => onHoldChrome?.call(false),
                                    items: [
                                      PopupMenuItem(
                                        value: '',
                                        child: Text(l10n.playerSubtitleOff),
                                      ),
                                      for (final t in subs)
                                        PopupMenuItem(
                                          value: t.id,
                                          child: Text(t.label),
                                        ),
                                    ],
                                    onSelected: (id) {
                                      if (id.isEmpty) {
                                        onSubtitle(null);
                                        return;
                                      }
                                      final t = subs.firstWhere(
                                        (e) => e.id == id,
                                        orElse: () => subs.first,
                                      );
                                      onSubtitle(t);
                                    },
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
                            );
                            // Narrow / short-height player: allow horizontal scroll
                            // instead of RenderFlex overflow.
                            if (rowConstraints.maxWidth < 520) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: rowConstraints.maxWidth,
                                  ),
                                  child: controls,
                                ),
                              );
                            }
                            return controls;
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Compact popup menu trigger used by quality / audio / speed / subtitle.
class PlayerTextMenuButton extends StatelessWidget {
  const PlayerTextMenuButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.colors,
    required this.items,
    required this.onSelected,
    this.onOpened,
    this.onClosed,
  });

  final String label;
  final String tooltip;
  final PlayerColors colors;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onOpened: onOpened,
      onCanceled: onClosed,
      onSelected: (v) {
        onClosed?.call();
        onSelected(v);
      },
      itemBuilder: (context) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: colors.controlFg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Display label for playback rate (e.g. `1x`, `1.5x`).
String playerSpeedLabel(double rate) {
  if (rate == rate.roundToDouble()) {
    return '${rate.toStringAsFixed(0)}x';
  }
  return '${rate}x';
}

/// `m:ss` or `h:mm:ss` for player time readout.
String formatPlayerDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '${d.inMinutes}:$s';
}
