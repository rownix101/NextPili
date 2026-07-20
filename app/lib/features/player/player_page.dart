import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
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
        // Prefer re-fetch when server may gate higher qn streams.
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _load(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Center(child: CircularProgressIndicator())
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
                  child: _BottomChrome(adapter: _adapter),
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
  });

  final String title;
  final VoidCallback onBack;
  final List<StreamDto> qualities;
  final StreamDto? current;
  final ValueChanged<StreamDto> onQuality;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (qualities.isNotEmpty)
            PopupMenuButton<StreamDto>(
              tooltip: '清晰度',
              icon: Text(
                current?.qualityLabel ?? '清晰度',
                style: const TextStyle(color: Colors.white),
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
  const _BottomChrome({required this.adapter});

  final MediaKitPlayerAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final player = adapter.player;
    return Material(
      color: Colors.black54,
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
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (playing) {
                                  adapter.pause();
                                } else {
                                  adapter.play();
                                }
                              },
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_fmt(pos)} / ${_fmt(dur)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '全屏（占位）',
                              onPressed: () {
                                // Desktop: toggle immersive chrome later.
                                SystemChrome.setEnabledSystemUIMode(
                                  SystemUiMode.immersiveSticky,
                                );
                              },
                              icon: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
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
