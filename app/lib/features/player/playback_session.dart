import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';
import '../../core/adaptive/desktop_os_fullscreen.dart';
import 'player_adapter.dart';

/// Pure host policy for [PlaybackSession.releaseInline] (related push/pop).
///
/// Returns `null` when the release should no-op; otherwise the next host.
@visibleForTesting
PlayerSurfaceHost? releaseInlineNextHost({
  required bool ownsTarget,
  required PlayerSurfaceHost host,
  required bool loading,
  required bool playing,
  required bool preferMini,
}) {
  if (!ownsTarget) return null;
  if (host != PlayerSurfaceHost.inline) return null;
  if (loading) return null;
  if (playing && preferMini) return PlayerSurfaceHost.mini;
  return PlayerSurfaceHost.idle;
}

/// Where the single [Video] surface is attached.
///
/// Only one host may render the media_kit surface at a time so progress,
/// audio, and decoder state stay continuous across fullscreen / mini.
enum PlayerSurfaceHost {
  /// Session may be open but no surface attached.
  idle,

  /// Watch-page / season-page inline slot.
  inline,

  /// OS window fullscreen + app immersive overlay (same decoder instance).
  fullscreen,

  /// Floating mini window while the inline slot is gone or covered.
  mini,
}

/// Identifies one open playurl target.
class PlaybackTarget {
  const PlaybackTarget({
    required this.videoId,
    required this.cid,
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.qn = 0,
    this.epId = 0,
  });

  final String videoId;
  final int cid;
  final int aid;
  final String bvid;
  final String title;
  final int qn;

  /// When > 0, stream via PGC playurl (`ep_id` + `cid`).
  final int epId;

  /// Identity of the playing archive (UGC/PGC + page), **not** stream preference.
  ///
  /// [qn] is excluded: clarity is a source preference mutated by
  /// [PlaybackSession.switchQuality]. Inline [PlayerPane] often keeps default
  /// `qn: 0` while session holds the selected qn — comparing qn would drop
  /// [ownsSurface] and tear down the media_kit [Video] after a quality pick.
  bool sameMedia(PlaybackTarget other) =>
      videoId == other.videoId && cid == other.cid && epId == other.epId;

  PlaybackTarget copyWith({
    String? videoId,
    int? cid,
    int? aid,
    String? bvid,
    String? title,
    int? qn,
    int? epId,
  }) {
    return PlaybackTarget(
      videoId: videoId ?? this.videoId,
      cid: cid ?? this.cid,
      aid: aid ?? this.aid,
      bvid: bvid ?? this.bvid,
      title: title ?? this.title,
      qn: qn ?? this.qn,
      epId: epId ?? this.epId,
    );
  }
}

class PlaybackSessionState {
  const PlaybackSessionState({
    this.target,
    this.host = PlayerSurfaceHost.idle,
    this.loading = false,
    this.error,
    this.danmakuOn = true,
    this.resolvedAid = 0,
  });

  final PlaybackTarget? target;
  final PlayerSurfaceHost host;
  final bool loading;
  final String? error;
  final bool danmakuOn;
  final int resolvedAid;

  bool get isActive => target != null;

  PlaybackSessionState copyWith({
    PlaybackTarget? target,
    PlayerSurfaceHost? host,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? danmakuOn,
    int? resolvedAid,
    bool clearTarget = false,
  }) {
    return PlaybackSessionState(
      target: clearTarget ? null : (target ?? this.target),
      host: host ?? this.host,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      danmakuOn: danmakuOn ?? this.danmakuOn,
      resolvedAid: resolvedAid ?? this.resolvedAid,
    );
  }
}

/// App-scoped playback session — one decoder, continuous position.
///
/// design/media §5 · interaction §4.4 (fullscreen / mini without remount).
class PlaybackSession extends Notifier<PlaybackSessionState> {
  MediaKitPlayerAdapter? _adapter;
  int _openGen = 0;

  MediaKitPlayerAdapter? get adapterOrNull => _adapter;

  MediaKitPlayerAdapter get adapter {
    final a = _adapter;
    if (a == null) {
      throw StateError('playback session has no adapter');
    }
    return a;
  }

  @override
  PlaybackSessionState build() {
    ref.onDispose(() {
      _teardown();
    });
    return const PlaybackSessionState();
  }

  /// Open (or reuse) media for [target] and attach surface to [host].
  ///
  /// Always re-asserts [host] on success so a mid-flight [releaseInline]
  /// (stacked `/video` routes, hero/offstage) cannot leave the surface stuck
  /// on [PlayerSurfaceHost.mini] / [PlayerSurfaceHost.idle] while the new
  /// watch page never paints [Video].
  Future<void> open(
    PlaybackTarget target, {
    PlayerSurfaceHost host = PlayerSurfaceHost.inline,
  }) async {
    final existing = state.target;
    if (existing != null &&
        existing.sameMedia(target) &&
        _adapter != null &&
        !state.loading &&
        state.error == null) {
      // Reclaim host without re-open. Preserve session qn/aid when the claimer
      // still carries defaults (inline watch page never tracks selected qn).
      state = state.copyWith(
        target: existing.copyWith(
          aid: target.aid != 0 ? target.aid : existing.aid,
          bvid: target.bvid.isNotEmpty ? target.bvid : existing.bvid,
          title: target.title.isNotEmpty ? target.title : existing.title,
          qn: target.qn != 0 ? target.qn : existing.qn,
        ),
      );
      setHost(host);
      return;
    }

    _adapter ??= MediaKitPlayerAdapter();
    final gen = ++_openGen;
    state = state.copyWith(
      target: target,
      host: host,
      loading: true,
      clearError: true,
    );
    _syncOsFullscreen(host);

    try {
      final source = await _fetchSource(target);
      if (gen != _openGen) return;
      await _adapter!.open(source);
      final aid = target.aid != 0 ? target.aid : i64(source.aid);
      final bvid = target.bvid.isNotEmpty ? target.bvid : source.bvid;
      await CoreApi.instance.playbackStart(
        aid: aid,
        bvid: bvid,
        cid: target.cid,
      );
      if (gen != _openGen) return;
      // Re-assert host: releaseInline may have demoted to mini/idle while the
      // playurl was in flight (previous video page still mounted under push).
      state = state.copyWith(
        target: target.copyWith(aid: aid, bvid: bvid),
        host: host,
        loading: false,
        resolvedAid: aid,
        clearError: true,
      );
      _syncOsFullscreen(host);
    } catch (e) {
      if (gen != _openGen) return;
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<MediaSourceDto> _fetchSource(PlaybackTarget target, {int? qn}) {
    final q = qn ?? target.qn;
    if (target.epId > 0) {
      return CoreApi.instance.pgcPlayUrl(
        epId: target.epId,
        cid: target.cid,
        qn: q,
      );
    }
    return CoreApi.instance.playUrl(
      id: target.videoId,
      cid: target.cid,
      qn: q,
    );
  }

  /// Move the single media_kit surface. Briefly parks on [idle] so two
  /// [Video] widgets never share one controller in the same frame.
  ///
  /// OS fullscreen tracks the **destination** host immediately (including during
  /// the idle park) so the window does not lag one frame behind the overlay.
  void setHost(PlayerSurfaceHost host) {
    if (state.target == null) return;
    if (state.host == host) return;
    final from = state.host;
    if (from != PlayerSurfaceHost.idle && host != PlayerSurfaceHost.idle) {
      // Destination OS state first — leave FS before shell can paint under it.
      _syncOsFullscreen(host);
      state = state.copyWith(host: PlayerSurfaceHost.idle);
      Future.microtask(() {
        if (state.target == null) return;
        if (state.host != PlayerSurfaceHost.idle) return;
        state = state.copyWith(host: host);
      });
      return;
    }
    state = state.copyWith(host: host);
    _syncOsFullscreen(host);
  }

  void enterFullscreen() => setHost(PlayerSurfaceHost.fullscreen);

  void exitFullscreen() {
    if (state.host != PlayerSurfaceHost.fullscreen) return;
    // Prefer inline if the watch slot is still mounted.
    setHost(PlayerSurfaceHost.inline);
  }

  /// Drive native window fullscreen when [host] is [PlayerSurfaceHost.fullscreen].
  void _syncOsFullscreen(PlayerSurfaceHost host) {
    // ignore: discarded_futures
    DesktopOsFullscreen.setEnabled(host == PlayerSurfaceHost.fullscreen);
  }

  void enterMini() {
    if (state.target == null) return;
    if (state.host == PlayerSurfaceHost.fullscreen) return;
    setHost(PlayerSurfaceHost.mini);
  }

  /// Inline slot left the tree (route covered or popped).
  ///
  /// Deferred one microtask so a same-frame [open] (cid switch / new watch
  /// page) can claim first without falsely demoting the surface.
  ///
  /// - [preferMini] true (route popped / leave watch): playing → mini.
  /// - [preferMini] false (covered by another route): detach to idle so the
  ///   incoming watch page can [open] without a mini flash of the old video.
  /// - No-ops when [state.loading] — an in-flight [open] owns host lifecycle.
  /// - No-ops when [state.target] is already a different media (new page won).
  void releaseInline(
    PlaybackTarget forTarget, {
    bool preferMini = true,
  }) {
    Future.microtask(() {
      final t = state.target;
      final next = releaseInlineNextHost(
        ownsTarget: t != null && t.sameMedia(forTarget),
        host: state.host,
        loading: state.loading,
        playing: _adapter?.player.state.playing ?? false,
        preferMini: preferMini,
      );
      if (next == null) return;
      setHost(next);
    });
  }

  /// Mini restore: jump back to the watch route owner; host → inline.
  void restoreFromMini() {
    if (state.host != PlayerSurfaceHost.mini) return;
    setHost(PlayerSurfaceHost.inline);
  }

  void toggleDanmaku() {
    state = state.copyWith(danmakuOn: !state.danmakuOn);
  }

  Future<void> switchQuality(StreamDto stream) async {
    final t = state.target;
    final a = _adapter;
    if (t == null || a == null) return;

    if (stream.qn != null) {
      final pos = a.player.state.position;
      final rate = a.rate;
      final prevSub = a.currentSubtitle;
      final source = await _fetchSource(t, qn: stream.qn);
      await a.open(source);
      if (rate != 1.0) await a.setRate(rate);
      if (pos > Duration.zero) await a.seek(pos);
      if (prevSub != null) {
        final match = source.subtitles
            .where((x) => x.id == prevSub.id || x.url == prevSub.url)
            .toList();
        if (match.isNotEmpty) {
          await switchSubtitle(match.first);
        }
      }
      state = state.copyWith(target: t.copyWith(qn: stream.qn!));
    } else {
      await a.setQuality(stream.id);
    }
  }

  Future<void> switchAudio(StreamDto stream) async {
    await _adapter?.setAudio(stream.id);
  }

  Future<void> switchSpeed(double rate) async {
    await _adapter?.setRate(rate);
  }

  Future<void> switchSubtitle(SubtitleTrackDto? track) async {
    final a = _adapter;
    if (a == null) return;
    if (track == null) {
      await a.setSubtitle();
      return;
    }
    final vtt = await CoreApi.instance.subtitleVtt(track.url);
    await a.setSubtitle(
      id: track.id,
      vtt: vtt,
      title: track.label,
      language: track.lang,
    );
  }

  Future<void> retry() async {
    final t = state.target;
    if (t == null) return;
    await open(t, host: state.host == PlayerSurfaceHost.idle
        ? PlayerSurfaceHost.inline
        : state.host);
  }

  /// Hard stop: heartbeat off + dispose decoder.
  Future<void> close() async {
    _openGen++;
    await DesktopOsFullscreen.setEnabled(false);
    await _teardown();
    state = const PlaybackSessionState();
  }

  Future<void> _teardown() async {
    CoreApi.instance.playbackStop();
    final a = _adapter;
    _adapter = null;
    if (a != null) {
      await a.dispose();
    }
  }
}

final playbackSessionProvider =
    NotifierProvider<PlaybackSession, PlaybackSessionState>(
  PlaybackSession.new,
);
