import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'danmaku_overlay.dart';
import 'playback_session.dart';
import 'player_adapter.dart';

/// Inline (or host-bound) video surface + chrome for one cid.
///
/// Uses [playbackSessionProvider] so fullscreen / mini never remount the
/// decoder — progress and audio stay continuous.
class PlayerPane extends ConsumerStatefulWidget {
  const PlayerPane({
    super.key,
    required this.videoId,
    required this.cid,
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.qn = 0,
    this.epId = 0,
    this.host = PlayerSurfaceHost.inline,
    this.immersive = false,
    this.showBack = false,
    this.onBack,
  });

  final String videoId;
  final int cid;
  final int aid;
  final String bvid;
  final String title;
  final int qn;

  /// When > 0, fetch stream via PGC playurl (`ep_id` + `cid`).
  final int epId;

  /// Which surface host this pane claims when active.
  final PlayerSurfaceHost host;

  /// Full-bleed chrome (fullscreen overlay).
  final bool immersive;

  final bool showBack;

  final VoidCallback? onBack;

  @override
  ConsumerState<PlayerPane> createState() => _PlayerPaneState();
}

class _PlayerPaneState extends ConsumerState<PlayerPane> {
  bool _showChrome = true;
  bool _chromeHeld = false;
  Timer? _chromeHideTimer;

  PlaybackTarget get _target => PlaybackTarget(
        videoId: widget.videoId,
        cid: widget.cid,
        aid: widget.aid,
        bvid: widget.bvid,
        title: widget.title,
        qn: widget.qn,
        epId: widget.epId,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(playbackSessionProvider.notifier).open(
            _target,
            host: widget.host,
          );
      _scheduleChromeHide();
    });
  }

  @override
  void dispose() {
    _chromeHideTimer?.cancel();
    super.dispose();
  }

  void _scheduleChromeHide() {
    _chromeHideTimer?.cancel();
    if (_chromeHeld || !_showChrome) return;
    _chromeHideTimer = Timer(AppDuration.playerChromeDelay, () {
      if (!mounted || _chromeHeld) return;
      setState(() => _showChrome = false);
    });
  }

  void _setChromeVisible(bool visible) {
    _chromeHideTimer?.cancel();
    if (_showChrome == visible) {
      if (visible) _scheduleChromeHide();
      return;
    }
    setState(() => _showChrome = visible);
    if (visible) _scheduleChromeHide();
  }

  void _toggleChrome() {
    _setChromeVisible(!_showChrome);
  }

  void _holdChrome(bool held) {
    _chromeHeld = held;
    if (held) {
      _chromeHideTimer?.cancel();
      if (!_showChrome) setState(() => _showChrome = true);
    } else {
      _scheduleChromeHide();
    }
  }

  void _bumpChrome() {
    if (!_showChrome) {
      _setChromeVisible(true);
    } else {
      _scheduleChromeHide();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cid != widget.cid ||
        oldWidget.videoId != widget.videoId ||
        oldWidget.qn != widget.qn ||
        oldWidget.epId != widget.epId ||
        oldWidget.host != widget.host) {
      ref.read(playbackSessionProvider.notifier).open(
            _target,
            host: widget.host,
          );
    }
  }

  @override
  void deactivate() {
    // Only the inline host auto-promotes to mini on leave; overlays manage exit.
    if (widget.host == PlayerSurfaceHost.inline) {
      ref.read(playbackSessionProvider.notifier).releaseInline(_target);
    }
    super.deactivate();
  }

  Future<void> _switchQuality(StreamDto stream) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchQuality(stream);
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  Future<void> _switchAudio(StreamDto stream) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchAudio(stream);
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  Future<void> _switchSpeed(double rate) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchSpeed(rate);
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  Future<void> _switchSubtitle(SubtitleTrackDto? track) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchSubtitle(track);
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      await Haptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playbackSessionProvider);
    final notifier = ref.read(playbackSessionProvider.notifier);
    final adapter = notifier.adapterOrNull;
    final player = PlayerColors.of(context);
    final l10n = context.l10n;

    final ownsSurface = session.host == widget.host &&
        session.target != null &&
        session.target!.sameMedia(_target);

    // Another host owns the surface (e.g. fullscreen while inline is mounted).
    if (!ownsSurface &&
        session.target != null &&
        session.target!.sameMedia(_target) &&
        !session.loading) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(
            AppIcons.playCircle,
            color: player.controlFgMuted,
            size: 40,
          ),
        ),
      );
    }

    final error = ownsSurface ? session.error : null;
    final loading = ownsSurface && (session.loading || adapter == null);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      errorMessage(error, l10n),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: player.controlFg),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => notifier.retry(),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else if (loading)
            const AppLoading()
          else if (ownsSurface && adapter != null)
            MouseRegion(
              onHover: (_) => _bumpChrome(),
              child: GestureDetector(
                onTap: _toggleChrome,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: adapter.controller,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                    if (session.resolvedAid > 0)
                      DanmakuOverlay(
                        aid: session.resolvedAid,
                        cid: widget.cid,
                        position: adapter.player.stream.position,
                        playing: adapter.player.stream.playing,
                        initialPlaying: adapter.player.state.playing,
                        enabled: session.danmakuOn,
                      ),
                  ],
                ),
              ),
            )
          else
            const AppLoading(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: AnimatedOpacity(
                opacity: _showChrome ? 1 : 0,
                duration: appMotionDuration(
                  context,
                  AppDuration.playerChrome,
                  reduced: AppDuration.short2,
                ),
                curve: AppEasing.standard,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopBar(
                        title: widget.title.isEmpty
                            ? widget.videoId
                            : widget.title,
                        showTitle: widget.immersive || widget.showBack,
                        showBack: widget.showBack,
                        colors: player,
                        onBack: widget.onBack,
                        danmakuOn: session.danmakuOn,
                        onToggleDanmaku: () {
                          _bumpChrome();
                          notifier.toggleDanmaku();
                        },
                        onFullscreen: widget.host ==
                                PlayerSurfaceHost.fullscreen
                            ? () => notifier.exitFullscreen()
                            : () => notifier.enterFullscreen(),
                        fullscreenExit:
                            widget.host == PlayerSurfaceHost.fullscreen,
                        onMini: widget.host == PlayerSurfaceHost.inline
                            ? () => notifier.enterMini()
                            : null,
                      ),
                    ),
                    if (!loading &&
                        error == null &&
                        ownsSurface &&
                        adapter != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _BottomChrome(
                          adapter: adapter,
                          colors: player,
                          onFullscreen: widget.host ==
                                  PlayerSurfaceHost.fullscreen
                              ? () => notifier.exitFullscreen()
                              : () => notifier.enterFullscreen(),
                          fullscreenExit:
                              widget.host == PlayerSurfaceHost.fullscreen,
                          onQuality: (s) {
                            _bumpChrome();
                            unawaited(_switchQuality(s));
                          },
                          onAudio: (s) {
                            _bumpChrome();
                            unawaited(_switchAudio(s));
                          },
                          onSpeed: (r) {
                            _bumpChrome();
                            unawaited(_switchSpeed(r));
                          },
                          onSubtitle: (t) {
                            _bumpChrome();
                            unawaited(_switchSubtitle(t));
                          },
                          onHoldChrome: _holdChrome,
                          onInteract: _bumpChrome,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
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

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.adapter,
    required this.colors,
    required this.onQuality,
    required this.onAudio,
    required this.onSpeed,
    required this.onSubtitle,
    this.onFullscreen,
    this.fullscreenExit = false,
    this.onHoldChrome,
    this.onInteract,
  });

  final MediaKitPlayerAdapter adapter;
  final PlayerColors colors;
  final ValueChanged<StreamDto> onQuality;
  final ValueChanged<StreamDto> onAudio;
  final ValueChanged<double> onSpeed;
  final ValueChanged<SubtitleTrackDto?> onSubtitle;
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
                final audios = adapter.audioOptions;
                final subs = adapter.subtitleOptions;
                final currentQ = adapter.currentVideo;
                final currentA = adapter.currentAudio;
                final currentSub = adapter.currentSubtitle;
                final rate = adapter.rate;

                return Material(
                  color: colors.chromeGlass,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                  '${_fmt(pos)} / ${_fmt(dur)}',
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
                                  _TextMenuButton(
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
                                if (audios.length > 1 ||
                                    (audios.length == 1 &&
                                        (audios.first.role == 'dolby' ||
                                            audios.first.role == 'hires')))
                                  _TextMenuButton(
                                    label: currentA?.qualityLabel ??
                                        l10n.playerAudio,
                                    tooltip: l10n.playerAudio,
                                    colors: colors,
                                    onOpened: () => onHoldChrome?.call(true),
                                    onClosed: () => onHoldChrome?.call(false),
                                    items: [
                                      for (final a in audios)
                                        PopupMenuItem(
                                          value: a.id,
                                          child: Text(a.qualityLabel),
                                        ),
                                    ],
                                    onSelected: (id) {
                                      final a = audios.firstWhere(
                                        (e) => e.id == id,
                                        orElse: () => audios.first,
                                      );
                                      onAudio(a);
                                    },
                                  ),
                                _TextMenuButton(
                                  label: _speedLabel(rate),
                                  tooltip: l10n.playerSpeed,
                                  colors: colors,
                                  onOpened: () => onHoldChrome?.call(true),
                                  onClosed: () => onHoldChrome?.call(false),
                                  items: [
                                    for (final r in MediaKitPlayerAdapter
                                        .speedOptions)
                                      PopupMenuItem(
                                        value: r.toString(),
                                        child: Text(_speedLabel(r)),
                                      ),
                                  ],
                                  onSelected: (v) {
                                    final r = double.tryParse(v);
                                    if (r != null) onSpeed(r);
                                  },
                                ),
                                if (subs.isNotEmpty)
                                  _TextMenuButton(
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

class _TextMenuButton extends StatelessWidget {
  const _TextMenuButton({
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

String _speedLabel(double rate) {
  if (rate == rate.roundToDouble()) {
    return '${rate.toStringAsFixed(0)}x';
  }
  return '${rate}x';
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '${d.inMinutes}:$s';
}
