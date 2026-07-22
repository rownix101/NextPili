import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'player_settings_local_state.dart';
import 'player_settings_overlay.dart';
import 'player_top_bar.dart';
import 'subtitle_overlay.dart';
import '../../core/widgets/app_snack_bar.dart';

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
    this.autoPlay = true,
    this.onAutoPlayChanged,
    this.onAutoPlayNext,
    this.theaterMode = false,
    this.onTheaterModeChanged,
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

  /// When true, request next part/video after playback completes.
  final bool autoPlay;

  final ValueChanged<bool>? onAutoPlayChanged;

  /// Invoked once when the active media completes and [autoPlay] is on.
  final VoidCallback? onAutoPlayNext;

  /// Theater layout (watch page expands player / hides rail).
  final bool theaterMode;

  final ValueChanged<bool>? onTheaterModeChanged;

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
  bool _settingsOpen = false;
  PlayerSettingsLocalState _settingsLocal = const PlayerSettingsLocalState();
  late final FocusNode _paneFocus =
      FocusNode(debugLabel: 'player.pane.settings');

  /// Last non-null subtitle so bottom-bar toggle can restore language.
  SubtitleTrackDto? _lastSubtitleTrack;
  StreamSubscription<bool>? _completedSub;
  bool _autoPlayNextArmed = true;
  late bool _autoPlay;

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
    _autoPlay = widget.autoPlay;
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
    unawaited(_completedSub?.cancel());
    _dmComposer.dispose();
    _paneFocus.dispose();
    super.dispose();
  }

  void _bindCompletedListener(MediaKitPlayerAdapter adapter) {
    if (_completedSub != null) return;
    _completedSub = adapter.player.stream.completed.listen((done) {
      if (!done || !mounted) return;
      if (!_autoPlayNextArmed) return;
      if (!_autoPlay) return;
      final next = widget.onAutoPlayNext;
      if (next == null) return;
      _autoPlayNextArmed = false;
      next();
    });
  }

  void _claimSession() {
    ref.read(playbackSessionProvider.notifier).open(
          _target,
          host: widget.host,
        );
  }

  /// Riverpod forbids provider writes during build/dependency resolution.
  /// [RouteObserver.subscribe] calls [didPush] synchronously from
  /// [didChangeDependencies], so session open/release must run after the frame.
  void _claimSessionSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _claimSession();
    });
  }

  void _releaseInline({required bool preferMini}) {
    if (widget.host != PlayerSurfaceHost.inline) return;
    ref.read(playbackSessionProvider.notifier).releaseInline(
          _target,
          preferMini: preferMini,
        );
  }

  void _releaseInlineSoon({required bool preferMini}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _releaseInline(preferMini: preferMini);
    });
  }

  @override
  void didPush() {
    // subscribe → didPush is sync during didChangeDependencies; defer open.
    // May race initState post-frame claim; sameMedia short-circuits.
    _claimSessionSoon();
  }

  @override
  void didPopNext() {
    // Route above us was popped (e.g. related video → back to this watch page).
    _claimSessionSoon();
  }

  @override
  void didPushNext() {
    // Covered by another *page* route (related push). Detach without mini so
    // the new watch page can open cleanly; mini is for leaving the watch stack.
    // PopupMenu/showMenu must NOT reach here — appRouteObserver is PageRoute-only.
    _releaseInlineSoon(preferMini: false);
  }

  @override
  void didPop() {
    // This watch page left the stack. Mini if still owning and playing.
    // Route is already leaving; fire release immediately (not post-frame —
    // widget may unmount before the next frame callback runs).
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
      AppSnackBar.show(context, message: l10n.playerDanmakuEmpty);
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
      AppSnackBar.show(context, message: l10n.playerDanmakuSent);
    } catch (e) {
      if (!mounted) return;
      await Haptics.error();
      if (!mounted) return;
      setState(() => _sendingDm = false);
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
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
    if (_settingsOpen) {
      _holdChrome(true);
      return;
    }
    if (!_showChrome) {
      _setChromeVisible(true);
    } else {
      _scheduleChromeHide();
    }
  }

  void _setSettingsOpen(bool open) {
    if (_settingsOpen == open) return;
    setState(() => _settingsOpen = open);
    if (open) {
      _holdChrome(true);
      _paneFocus.requestFocus();
    } else {
      _holdChrome(false);
    }
  }

  void _toggleSettings() {
    _setSettingsOpen(!_settingsOpen);
  }

  void _closeSettings() {
    if (_settingsOpen) _setSettingsOpen(false);
  }

  KeyEventResult _onPaneKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _settingsOpen) {
      _closeSettings();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant PlayerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay && widget.autoPlay != _autoPlay) {
      _autoPlay = widget.autoPlay;
    }
    if (oldWidget.cid != widget.cid ||
        oldWidget.videoId != widget.videoId ||
        oldWidget.qn != widget.qn ||
        oldWidget.epId != widget.epId ||
        oldWidget.host != widget.host) {
      _autoPlayNextArmed = true;
      // didUpdateWidget runs during rebuild — defer provider write.
      _claimSessionSoon();
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
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
    }
  }

  Future<void> _switchSpeed(double rate) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchSpeed(rate);
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
    }
  }

  Future<void> _switchSubtitle(SubtitleTrackDto? track) async {
    try {
      await ref.read(playbackSessionProvider.notifier).switchSubtitle(track);
      if (track != null) _lastSubtitleTrack = track;
      await Haptics.selection();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      await Haptics.error();
      if (!mounted) return;
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
    }
  }

  Future<void> _toggleSubtitles(MediaKitPlayerAdapter adapter) async {
    final current = adapter.currentSubtitle;
    if (current != null) {
      _lastSubtitleTrack = current;
      await _switchSubtitle(null);
      return;
    }
    final tracks = adapter.subtitleOptions;
    if (tracks.isEmpty) return;
    SubtitleTrackDto? restore = _lastSubtitleTrack;
    if (restore != null) {
      final stillThere = tracks.any((t) => t.id == restore!.id);
      if (!stillThere) restore = null;
    }
    await _switchSubtitle(restore ?? tracks.first);
  }

  void _toggleAutoPlay() {
    final next = !_autoPlay;
    setState(() {
      _autoPlay = next;
      _autoPlayNextArmed = true;
    });
    widget.onAutoPlayChanged?.call(next);
    unawaited(Haptics.selection());
  }

  void _toggleTheater() {
    final next = !widget.theaterMode;
    widget.onTheaterModeChanged?.call(next);
    unawaited(Haptics.selection());
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
        _bindCompletedListener(adapter);
        _syncPremiumAudioToast(adapter);
      });
    }

    final chromeVisible = _showChrome || _settingsOpen;

    return Focus(
      focusNode: _paneFocus,
      onKeyEvent: _onPaneKey,
      child: ColoredBox(
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
                  onTap: () {
                    if (_settingsOpen) {
                      _closeSettings();
                      return;
                    }
                    _toggleChrome();
                  },
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
            if (_settingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeSettings,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !chromeVisible,
                child: AnimatedOpacity(
                  opacity: chromeVisible ? 1 : 0,
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
                              unawaited(
                                _sendDanmaku(adapter).whenComplete(() {
                                  if (mounted && !_settingsOpen) {
                                    _holdChrome(false);
                                  }
                                }),
                              );
                            },
                            onDmFocus: (focused) {
                              if (focused) {
                                _holdChrome(true);
                              } else if (!_settingsOpen) {
                                _holdChrome(false);
                              }
                            },
                            onFullscreen: widget.host ==
                                    PlayerSurfaceHost.fullscreen
                                ? () => notifier.exitFullscreen()
                                : () => notifier.enterFullscreen(),
                            fullscreenExit:
                                widget.host == PlayerSurfaceHost.fullscreen,
                            autoPlay: _autoPlay,
                            subtitlesOn: adapter.currentSubtitle != null,
                            subtitlesAvailable:
                                adapter.subtitleOptions.isNotEmpty,
                            onToggleAutoPlay: () {
                              _bumpChrome();
                              _toggleAutoPlay();
                            },
                            onToggleSubtitles: () {
                              _bumpChrome();
                              unawaited(_toggleSubtitles(adapter));
                            },
                            onToggleTheater:
                                widget.onTheaterModeChanged == null ||
                                        widget.host !=
                                            PlayerSurfaceHost.inline
                                    ? null
                                    : () {
                                        _bumpChrome();
                                        _toggleTheater();
                                      },
                            theaterMode: widget.theaterMode,
                            onHoldChrome: (held) {
                              if (!held && _settingsOpen) return;
                              _holdChrome(held);
                            },
                            onInteract: _bumpChrome,
                            onToggleSettings: _toggleSettings,
                            settingsOpen: _settingsOpen,
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
                adapter != null)
              Positioned(
                top: 56,
                right: AppSpacing.sm,
                bottom: 72,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PlayerSettingsOverlayHost(
                    visible: _settingsOpen,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth.clamp(0.0, 320.0);
                        final width =
                            maxW < 240 ? maxW : kPlayerSettingsPanelWidth;
                        final q = adapter.currentVideo;
                        final sub = adapter.currentSubtitle;
                        return SizedBox(
                          width: width.clamp(0.0, kPlayerSettingsPanelWidth),
                          child: PlayerSettingsOverlay(
                            colors: player,
                            local: _settingsLocal,
                            onLocalChanged: (s) {
                              setState(() => _settingsLocal = s);
                            },
                            qualityLabel:
                                q?.qualityLabel ?? l10n.playerQuality,
                            speedLabel: playerSpeedLabel(adapter.rate),
                            currentSpeed: adapter.rate,
                            currentQualityId: q?.id,
                            subtitleLabel:
                                sub?.label ?? l10n.playerSubtitleOff,
                            currentSubtitleId: sub?.id,
                            qualities: adapter.qualityOptions,
                            subtitleTracks: adapter.subtitleOptions,
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
                            onInteract: _bumpChrome,
                          ),
                        );
                      },
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
      ),
    );
  }
}
