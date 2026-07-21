import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_session.dart';

/// Deep-link immersive route `/play/:id`.
///
/// Watch-page fullscreen uses [PlaybackSession.enterFullscreen] (OS window
/// fullscreen + app overlay) and does **not** push this route. This page only
/// seeds the shared session; the surface is drawn by [PlayerOverlayLayer].
class PlayerPage extends ConsumerStatefulWidget {
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
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(playbackSessionProvider.notifier).open(
            PlaybackTarget(
              videoId: widget.videoId,
              cid: widget.cid,
              aid: widget.aid,
              bvid: widget.bvid,
              title: widget.title,
              qn: widget.qn,
            ),
            host: PlayerSurfaceHost.fullscreen,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (ref.read(playbackSessionProvider).host ==
            PlayerSurfaceHost.fullscreen) {
          ref.read(playbackSessionProvider.notifier).exitFullscreen();
        }
      },
      child: const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      ),
    );
  }
}
