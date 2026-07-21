import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/widgets/glass/glass_panel.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'player_adapter.dart';

/// Bottom chrome: danmaku composer, seek bar, transport + chrome toggles.
///
/// Right-side order: autoplay · subtitles · settings · theater · fullscreen.
/// Quality / speed / subtitle language live in [PlayerSettingsOverlay].
///
/// Liquid Glass is **pill-scoped** to icon clusters only (design-system §2 —
/// not a full-width frosted bar over seek/danmaku).
class PlayerBottomChrome extends StatelessWidget {
  const PlayerBottomChrome({
    super.key,
    required this.adapter,
    required this.colors,
    required this.danmakuOn,
    required this.dmComposer,
    required this.sendingDm,
    required this.onSendDanmaku,
    required this.onDmFocus,
    required this.autoPlay,
    required this.subtitlesOn,
    required this.subtitlesAvailable,
    required this.onToggleAutoPlay,
    required this.onToggleSubtitles,
    this.onFullscreen,
    this.fullscreenExit = false,
    this.onHoldChrome,
    this.onInteract,
    this.onToggleSettings,
    this.settingsOpen = false,
    this.onToggleTheater,
    this.theaterMode = false,
  });

  final MediaKitPlayerAdapter adapter;
  final PlayerColors colors;
  final bool danmakuOn;
  final TextEditingController dmComposer;
  final bool sendingDm;
  final VoidCallback onSendDanmaku;
  final ValueChanged<bool> onDmFocus;
  final bool autoPlay;
  final bool subtitlesOn;
  final bool subtitlesAvailable;
  final VoidCallback onToggleAutoPlay;
  final VoidCallback onToggleSubtitles;
  final VoidCallback? onFullscreen;
  final bool fullscreenExit;
  final ValueChanged<bool>? onHoldChrome;
  final VoidCallback? onInteract;
  final VoidCallback? onToggleSettings;
  final bool settingsOpen;
  final VoidCallback? onToggleTheater;
  final bool theaterMode;

  static const double _pillRadius = AppShapes.full;
  static const double _pillPadH = 4;
  static const double _pillPadV = 2;

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

                // Soft bottom scrim for bare seek/danmaku readability — not glass.
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.scrimTop,
                        colors.scrimBottom,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                                  onPressed: sendingDm ? null : onSendDanmaku,
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
                            final transport = _GlassIconPill(
                              colors: colors,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NpIconButton(
                                    icon: playing
                                        ? AppIcons.pause
                                        : AppIcons.play,
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
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      '${formatPlayerDuration(pos)} / ${formatPlayerDuration(dur)}',
                                      style: TextStyle(
                                        color: colors.controlFgMuted,
                                        fontSize: 12,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            final chromeIcons = <Widget>[
                              NpIconButton(
                                icon: AppIcons.autoPlay,
                                color: autoPlay
                                    ? colors.progressPlayed
                                    : colors.controlFg,
                                onPressed: () {
                                  onInteract?.call();
                                  onToggleAutoPlay();
                                },
                                tooltip: autoPlay
                                    ? l10n.playerAutoPlayOn
                                    : l10n.playerAutoPlayOff,
                              ),
                              if (subtitlesAvailable)
                                NpIconButton(
                                  icon: subtitlesOn
                                      ? AppIcons.captions
                                      : AppIcons.captionsOff,
                                  color: subtitlesOn
                                      ? colors.progressPlayed
                                      : colors.controlFg,
                                  onPressed: () {
                                    onInteract?.call();
                                    onToggleSubtitles();
                                  },
                                  tooltip: subtitlesOn
                                      ? l10n.playerSubtitleToggleOff
                                      : l10n.playerSubtitleOn,
                                ),
                              if (onToggleSettings != null)
                                NpIconButton(
                                  icon: AppIcons.sliders,
                                  color: settingsOpen
                                      ? colors.progressPlayed
                                      : colors.controlFg,
                                  onPressed: () {
                                    onInteract?.call();
                                    onToggleSettings?.call();
                                  },
                                  tooltip: l10n.playerSettings,
                                ),
                              if (onToggleTheater != null)
                                NpIconButton(
                                  icon: theaterMode
                                      ? AppIcons.theaterExit
                                      : AppIcons.theater,
                                  color: theaterMode
                                      ? colors.progressPlayed
                                      : colors.controlFg,
                                  onPressed: () {
                                    onInteract?.call();
                                    onToggleTheater?.call();
                                  },
                                  tooltip: theaterMode
                                      ? l10n.playerTheaterExit
                                      : l10n.playerTheater,
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
                            ];

                            final actions = _GlassIconPill(
                              colors: colors,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: chromeIcons,
                              ),
                            );

                            final row = Row(
                              children: [
                                transport,
                                const Spacer(),
                                actions,
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
                                  child: row,
                                ),
                              );
                            }
                            return row;
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

/// Compact Liquid Glass pill around an icon cluster (not full-width chrome).
class _GlassIconPill extends StatelessWidget {
  const _GlassIconPill({
    required this.colors,
    required this.child,
  });

  final PlayerColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedSuperellipse(
        borderRadius: PlayerBottomChrome._pillRadius,
      ),
      settings: GlassPanel.playerChromeSettings(colors.chromeGlass),
      padding: const EdgeInsets.symmetric(
        horizontal: PlayerBottomChrome._pillPadH,
        vertical: PlayerBottomChrome._pillPadV,
      ),
      child: child,
    );
  }
}

/// Compact popup menu trigger used by subtitle (and similar chrome menus).
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
