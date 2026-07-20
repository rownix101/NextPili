import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'danmaku_overlay.dart';
import 'player_adapter.dart';

/// Video surface + chrome + danmaku for one cid.
///
/// Use inside a sized parent (e.g. [AspectRatio] 16:9) for watch page,
/// or expand to fill for immersive `/play`.
class PlayerPane extends StatefulWidget {
  const PlayerPane({
    super.key,
    required this.videoId,
    required this.cid,
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.qn = 0,
    this.epId = 0,
    this.immersive = false,
    this.showBack = false,
    this.onBack,
    this.onRequestFullscreen,
  });

  final String videoId;
  final int cid;
  final int aid;
  final String bvid;
  final String title;
  final int qn;

  /// When > 0, fetch stream via PGC playurl (`ep_id` + `cid`).
  final int epId;

  /// Full-bleed black chrome (route `/play`).
  final bool immersive;

  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onRequestFullscreen;

  @override
  State<PlayerPane> createState() => _PlayerPaneState();
}

class _PlayerPaneState extends State<PlayerPane> {
  late final MediaKitPlayerAdapter _adapter;
  bool _loading = true;
  String? _error;
  bool _showChrome = true;
  bool _danmakuOn = true;
  int _resolvedAid = 0;

  @override
  void initState() {
    super.initState();
    _adapter = MediaKitPlayerAdapter();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cid != widget.cid ||
        oldWidget.videoId != widget.videoId ||
        oldWidget.qn != widget.qn ||
        oldWidget.epId != widget.epId) {
      _load();
    }
  }

  Future<MediaSourceDto> _fetchSource(int qn) {
    if (widget.epId > 0) {
      return CoreApi.instance.pgcPlayUrl(
        epId: widget.epId,
        cid: widget.cid,
        qn: qn,
      );
    }
    return CoreApi.instance.playUrl(
      id: widget.videoId,
      cid: widget.cid,
      qn: qn,
    );
  }

  Future<void> _load({int? qn}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final source = await _fetchSource(qn ?? widget.qn);
      if (!mounted) return;
      await _adapter.open(source);
      final aid = widget.aid != 0 ? widget.aid : i64(source.aid);
      final bvid = widget.bvid.isNotEmpty ? widget.bvid : source.bvid;
      await CoreApi.instance.playbackStart(
        aid: aid,
        bvid: bvid,
        cid: widget.cid,
      );
      if (!mounted) return;
      setState(() {
        _resolvedAid = aid;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _switchQuality(StreamDto stream) async {
    try {
      if (stream.qn != null) {
        final pos = _adapter.player.state.position;
        final source = await _fetchSource(stream.qn!);
        if (!mounted) return;
        await _adapter.open(source);
        if (pos > Duration.zero) {
          await _adapter.seek(pos);
        }
      } else {
        await _adapter.setQuality(stream.id);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  @override
  void dispose() {
    CoreApi.instance.playbackStop();
    _adapter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerColors.of(context);
    final l10n = context.l10n;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: player.controlFg),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _load,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else if (_loading)
            const AppLoading()
          else
            GestureDetector(
              onTap: () => setState(() => _showChrome = !_showChrome),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: _adapter.controller,
                    controls: NoVideoControls,
                    fill: Colors.black,
                  ),
                  if (_resolvedAid > 0)
                    DanmakuOverlay(
                      aid: _resolvedAid,
                      cid: widget.cid,
                      position: _adapter.player.stream.position,
                      playing: _adapter.player.stream.playing,
                      initialPlaying: _adapter.player.state.playing,
                      enabled: _danmakuOn,
                    ),
                ],
              ),
            ),
          if (_showChrome) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                title: widget.title.isEmpty ? widget.videoId : widget.title,
                showTitle: widget.immersive || widget.showBack,
                showBack: widget.showBack,
                colors: player,
                onBack: widget.onBack,
                qualities: _adapter.qualityOptions,
                current: _adapter.currentVideo,
                onQuality: _switchQuality,
                danmakuOn: _danmakuOn,
                onToggleDanmaku: () =>
                    setState(() => _danmakuOn = !_danmakuOn),
                onFullscreen: widget.onRequestFullscreen,
              ),
            ),
            if (!_loading && _error == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomChrome(
                  adapter: _adapter,
                  colors: player,
                  onFullscreen: widget.onRequestFullscreen,
                ),
              ),
          ],
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
    required this.qualities,
    required this.current,
    required this.onQuality,
    required this.colors,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    this.onFullscreen,
  });

  final String title;
  final bool showTitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<StreamDto> qualities;
  final StreamDto? current;
  final ValueChanged<StreamDto> onQuality;
  final PlayerColors colors;
  final bool danmakuOn;
  final VoidCallback onToggleDanmaku;
  final VoidCallback? onFullscreen;

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
          if (qualities.isNotEmpty)
            PopupMenuButton<StreamDto>(
              tooltip: l10n.playerQuality,
              icon: Text(
                current?.qualityLabel ?? l10n.playerQuality,
                style: TextStyle(color: colors.controlFg, fontSize: 13),
              ),
              onSelected: onQuality,
              itemBuilder: (context) => [
                for (final q in qualities)
                  PopupMenuItem(
                    value: q,
                    child: Text(q.qualityLabel),
                  ),
              ],
            ),
          if (onFullscreen != null)
            NpIconButton(
              icon: AppIcons.fullscreen,
              color: colors.controlFg,
              onPressed: onFullscreen,
              tooltip: l10n.playerFullscreen,
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
    this.onFullscreen,
  });

  final MediaKitPlayerAdapter adapter;
  final PlayerColors colors;
  final VoidCallback? onFullscreen;

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
                final maxMs = dur.inMilliseconds.toDouble().clamp(1.0, 1e12).toDouble();
                final value =
                    pos.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();

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
                            onChanged: (v) {
                              adapter.seek(Duration(milliseconds: v.round()));
                            },
                          ),
                        ),
                        Row(
                          children: [
                            NpIconButton(
                              icon: playing ? AppIcons.pause : AppIcons.play,
                              color: colors.controlFg,
                              onPressed: () {
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
                            if (onFullscreen != null)
                              NpIconButton(
                                icon: AppIcons.fullscreen,
                                color: colors.controlFg,
                                onPressed: onFullscreen,
                                tooltip: l10n.playerFullscreen,
                              ),
                          ],
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

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '${d.inMinutes}:$s';
}
