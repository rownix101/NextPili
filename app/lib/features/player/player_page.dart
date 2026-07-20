import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import 'player_adapter.dart';

/// Full-screen-ish player route for a single cid.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.videoId,
    required this.cid,
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.qn = 0,
  });

  final String videoId;
  final int cid;
  final int aid;
  final String bvid;
  final String title;
  final int qn;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final MediaKitPlayerAdapter _adapter;
  bool _loading = true;
  String? _error;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _adapter = MediaKitPlayerAdapter();
    _load();
  }

  Future<void> _load({int? qn}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final source = await CoreApi.instance.playUrl(
        id: widget.videoId,
        cid: widget.cid,
        qn: qn ?? widget.qn,
      );
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
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _switchQuality(StreamDto stream) async {
    try {
      if (stream.qn != null) {
        final pos = _adapter.player.state.position;
        final source = await CoreApi.instance.playUrl(
          id: widget.videoId,
          cid: widget.cid,
          qn: stream.qn!,
        );
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
        SnackBar(content: Text(errorMessage(e))),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
                        child: const Text('重试'),
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
                child: Center(
                  child: Video(
                    controller: _adapter.controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
            if (_showChrome) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  title: widget.title.isEmpty ? widget.videoId : widget.title,
                  colors: player,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  qualities: _adapter.qualityOptions,
                  current: _adapter.currentVideo,
                  onQuality: _switchQuality,
                ),
              ),
              if (!_loading && _error == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomChrome(adapter: _adapter, colors: player),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.qualities,
    required this.current,
    required this.onQuality,
    required this.colors,
  });

  final String title;
  final VoidCallback onBack;
  final List<StreamDto> qualities;
  final StreamDto? current;
  final ValueChanged<StreamDto> onQuality;
  final PlayerColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.chromeGlass,
      child: Row(
        children: [
          NpIconButton(
            icon: AppIcons.arrowLeft,
            color: colors.controlFg,
            onPressed: onBack,
            tooltip: '返回',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.controlFg, fontSize: 16),
            ),
          ),
          if (qualities.isNotEmpty)
            PopupMenuButton<StreamDto>(
              tooltip: '清晰度',
              icon: Text(
                current?.qualityLabel ?? '清晰度',
                style: TextStyle(color: colors.controlFg),
              ),
              onSelected: onQuality,
              itemBuilder: (context) => [
                for (final q in qualities)
                  PopupMenuItem(
                    value: q,
                    child: Text(
                      q.qualityLabel,
                      style: TextStyle(
                        fontWeight: current?.id == q.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({required this.adapter, required this.colors});

  final MediaKitPlayerAdapter adapter;
  final PlayerColors colors;

  @override
  Widget build(BuildContext context) {
    final player = adapter.player;
    return Material(
      color: colors.chromeGlass,
      child: StreamBuilder(
        stream: player.stream.position,
        builder: (context, posSnap) {
          return StreamBuilder(
            stream: player.stream.duration,
            builder: (context, durSnap) {
              return StreamBuilder(
                stream: player.stream.playing,
                builder: (context, playSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final dur = durSnap.data ?? Duration.zero;
                  final playing = playSnap.data ?? false;
                  final maxMs = dur.inMilliseconds <= 0
                      ? 1.0
                      : dur.inMilliseconds.toDouble();
                  final value = pos.inMilliseconds.clamp(0, maxMs.toInt());
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            NpIconButton(
                              onPressed: () {
                                if (playing) {
                                  adapter.pause();
                                } else {
                                  adapter.play();
                                }
                              },
                              icon: playing ? AppIcons.pause : AppIcons.play,
                              color: colors.controlFg,
                              tooltip: playing ? '暂停' : '播放',
                            ),
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
                            NpIconButton(
                              tooltip: '全屏（占位）',
                              onPressed: () {
                                SystemChrome.setEnabledSystemUIMode(
                                  SystemUiMode.immersiveSticky,
                                );
                              },
                              icon: AppIcons.fullscreen,
                              color: colors.controlFg,
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: colors.progressPlayed,
                            inactiveTrackColor: colors.progressTrack,
                            thumbColor: colors.progressPlayed,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: value.toDouble(),
                            max: maxMs,
                            onChanged: (v) {
                              adapter.seek(Duration(milliseconds: v.round()));
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
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
