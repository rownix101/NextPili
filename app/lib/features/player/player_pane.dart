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
import '../../l10n/l10n.dart';
import '../video/engagement_bar.dart' show ensureLoggedIn;
import 'danmaku_actions.dart';
import 'danmaku_overlay.dart';
import 'playback_session.dart';
import 'player_adapter.dart';
import 'player_bottom_chrome.dart';
import 'player_top_bar.dart';

/// Inline (or host-bound) video surface + chrome for one cid.
///
/// Uses [playbackSessionProvider] so fullscreen / mini never remount the
/// decoder — progress and audio stay continuous.
///
/// Chrome widgets live in [PlayerTopBar] / [PlayerBottomChrome]; this module
/// owns session host binding, chrome visibility policy, and stream switches.
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
  final GlobalKey<DanmakuOverlayState> _danmakuKey =
      GlobalKey<DanmakuOverlayState>();
  final TextEditingController _dmComposer = TextEditingController();
  bool _sendingDm = false;

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
    _dmComposer.dispose();
    super.dispose();
  }

  Future<void> _sendDanmaku(MediaKitPlayerAdapter adapter) async {
    final text = _dmComposer.text.trim();
    final l10n = context.l10n;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playerDanmakuEmpty)),
      );
      return;
    }
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    setState(() => _sendingDm = true);
    try {
      final pos = adapter.player.state.position.inMilliseconds;
      final posted = await CoreApi.instance.danmakuPost(
        oid: widget.cid,
        aid: widget.aid > 0
            ? widget.aid
            : ref.read(playbackSessionProvider).resolvedAid,
        bvid: widget.bvid,
        msg: text,
        progressMs: pos,
      );
      if (!mounted) return;
      await Haptics.success();
      _dmComposer.clear();
      _danmakuKey.currentState?.injectLocal(posted);
      setState(() => _sendingDm = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playerDanmakuSent)),
      );
    } catch (e) {
      if (!mounted) return;
      await Haptics.error();
      if (!mounted) return;
      setState(() => _sendingDm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
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
                        key: _danmakuKey,
                        aid: session.resolvedAid,
                        cid: widget.cid,
                        position: adapter.player.stream.position,
                        playing: adapter.player.stream.playing,
                        initialPlaying: adapter.player.state.playing,
                        enabled: session.danmakuOn,
                        playbackRate: adapter.rate,
                        onDanmakuLongPress: (item) {
                          unawaited(
                            showDanmakuActions(
                              context,
                              item: item,
                              cid: widget.cid,
                            ),
                          );
                        },
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
                      child: PlayerTopBar(
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
                        child: PlayerBottomChrome(
                          adapter: adapter,
                          colors: player,
                          danmakuOn: session.danmakuOn,
                          dmComposer: _dmComposer,
                          sendingDm: _sendingDm,
                          onSendDanmaku: () {
                            _holdChrome(true);
                            unawaited(_sendDanmaku(adapter).whenComplete(() {
                              if (mounted) _holdChrome(false);
                            }));
                          },
                          onDmFocus: (focused) => _holdChrome(focused),
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
