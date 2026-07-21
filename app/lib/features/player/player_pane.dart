import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/app_motion.dart';
import '../../core/router/route_observer.dart';
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
import 'player_premium_audio_toast.dart';
import 'player_top_bar.dart';
import 'subtitle_overlay.dart';

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

class _PlayerPaneState extends ConsumerState<PlayerPane> with RouteAware {
  bool _showChrome = true;
  bool _chromeHeld = false;
  Timer? _chromeHideTimer;
  final GlobalKey<DanmakuOverlayState> _danmakuKey =
      GlobalKey<DanmakuOverlayState>();
  final TextEditingController _dmComposer = TextEditingController();
  bool _sendingDm = false;
  String? _premiumToastKey;
  String? _premiumToastRole;
  bool _premiumToastVisible = false;
  Timer? _premiumToastTimer;
  Uint8List? _premiumFrostFrame;

  /// True when subscribed to [appRouteObserver] (inline watch-page only).
  bool _routeSubscribed = false;

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
      _claimSession();
      _scheduleChromeHide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inline watch slots live under ShellRoute → need cover/pop events so a
    // related push does not leave the previous video owning the decoder, and
    // pop restores the previous page's session. Overlay hosts (fullscreen /
    // mini) manage host themselves and skip RouteAware.
    if (widget.host != PlayerSurfaceHost.inline) return;
    final route = ModalRoute.of(context);
    if (_routeSubscribed || route is! PageRoute) return;
    appRouteObserver.subscribe(this, route);
    _routeSubscribed = true;
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
      _routeSubscribed = false;
    }
    _chromeHideTimer?.cancel();
    _premiumToastTimer?.cancel();
    _dmComposer.dispose();
    super.dispose();
  }

  void _claimSession() {
    ref.read(playbackSessionProvider.notifier).open(
          _target,
          host: widget.host,
        );
  }

  void _releaseInline({required bool preferMini}) {
    if (widget.host != PlayerSurfaceHost.inline) return;
    ref.read(playbackSessionProvider.notifier).releaseInline(
          _target,
          preferMini: preferMini,
        );
  }

  @override
  void didPush() {
    // First frame may race with initState post-frame; sameMedia short-circuits.
    _claimSession();
  }

  @override
  void didPopNext() {
    // Route above us was popped (e.g. related video → back to this watch page).
    _claimSession();
  }

  @override
  void didPushNext() {
    // Covered by another *page* route (related push). Detach without mini so
    // the new watch page can open cleanly; mini is for leaving the watch stack.
    // PopupMenu/showMenu must NOT reach here — appRouteObserver is PageRoute-only.
    _releaseInline(preferMini: false);
  }

  @override
  void didPop() {
    // This watch page left the stack. Mini if still owning and playing.
    _releaseInline(preferMini: true);
  }

  void _syncPremiumAudioToast(MediaKitPlayerAdapter adapter) {
    final audio = adapter.currentAudio;
    final role = audio?.role;
    if (!PlayerPremiumAudioToast.isPremiumRole(role) || audio == null) {
      if (_premiumToastVisible || _premiumToastRole != null) {
        _premiumToastTimer?.cancel();
        setState(() {
          _premiumToastVisible = false;
          _premiumToastRole = null;
          _premiumToastKey = null;
          _premiumFrostFrame = null;
        });
      }
      return;
    }
    final key = '${widget.videoId}:${widget.cid}:${audio.id}';
    if (_premiumToastKey == key) return;
    _premiumToastTimer?.cancel();
    setState(() {
      _premiumToastKey = key;
      _premiumToastRole = role;
      _premiumToastVisible = true;
      _premiumFrostFrame = null;
    });
    unawaited(_capturePremiumFrost(adapter, key));
    _premiumToastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _premiumToastVisible = false);
    });
  }

  /// Snapshot current frame so the toast can blur real video pixels.
  ///
  /// [BackdropFilter] cannot sample media_kit HW textures on desktop.
  Future<void> _capturePremiumFrost(
    MediaKitPlayerAdapter adapter,
    String toastKey,
  ) async {
    try {
      final bytes = await adapter.player.screenshot(format: 'image/jpeg');
      if (!mounted || bytes == null || bytes.isEmpty) return;
      if (_premiumToastKey != toastKey) return;
      setState(() => _premiumFrostFrame = bytes);
    } catch (_) {
      // Keep gradient plate fallback.
    }
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
      _claimSession();
    }
  }

  @override
  void deactivate() {
    // Fallback when RouteAware is not subscribed (non-PageRoute parent).
    // Stacked `/video` cover/pop is handled by didPushNext / didPop instead —
    // deactivate alone never runs on a mere push cover, which was the related
    // bug (previous video kept playing; new page never owned the surface).
    if (!_routeSubscribed && widget.host == PlayerSurfaceHost.inline) {
      _releaseInline(preferMini: true);
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

    if (ownsSurface && !loading && error == null && adapter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPremiumAudioToast(adapter);
      });
    }

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
                      // CC is drawn by [SubtitleOverlay] — disable media_kit
                      // SubtitleView so we never hit mpv sub-add mid-playback.
                      subtitleViewConfiguration:
                          const SubtitleViewConfiguration(visible: false),
                    ),
                    if (adapter.subtitleCues.isNotEmpty)
                      SubtitleOverlay(
                        position: adapter.player.stream.position,
                        cues: adapter.subtitleCues,
                        initialPosition: adapter.player.state.position,
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
          if (ownsSurface &&
              !loading &&
              error == null &&
              adapter != null &&
              _premiumToastRole != null)
            Positioned.fill(
              child: PlayerPremiumAudioToast(
                role: _premiumToastRole!,
                visible: _premiumToastVisible,
                frostFrame: _premiumFrostFrame,
              ),
            ),
        ],
      ),
    );
  }
}
