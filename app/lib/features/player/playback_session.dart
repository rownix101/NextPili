import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';
import 'player_adapter.dart';

/// Where the single [Video] surface is attached.
///
/// Only one host may render the media_kit surface at a time so progress,
/// audio, and decoder state stay continuous across fullscreen / mini.
enum PlayerSurfaceHost {
  /// Session may be open but no surface attached.
  idle,

  /// Watch-page / season-page inline slot.
  inline,

  /// App-level immersive overlay (not a new player instance).
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

  bool sameMedia(PlaybackTarget other) =>
      videoId == other.videoId &&
      cid == other.cid &&
      epId == other.epId &&
      qn == other.qn;

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
      state = state.copyWith(target: target);
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
      state = state.copyWith(
        target: target.copyWith(aid: aid, bvid: bvid),
        loading: false,
        resolvedAid: aid,
        clearError: true,
      );
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
  void setHost(PlayerSurfaceHost host) {
    if (state.target == null) return;
    if (state.host == host) return;
    final from = state.host;
    if (from != PlayerSurfaceHost.idle && host != PlayerSurfaceHost.idle) {
      state = state.copyWith(host: PlayerSurfaceHost.idle);
      Future.microtask(() {
        if (state.target == null) return;
        if (state.host != PlayerSurfaceHost.idle) return;
        state = state.copyWith(host: host);
      });
      return;
    }
    state = state.copyWith(host: host);
  }

  void enterFullscreen() => setHost(PlayerSurfaceHost.fullscreen);

  void exitFullscreen() {
    if (state.host != PlayerSurfaceHost.fullscreen) return;
    // Prefer inline if the watch slot is still mounted.
    setHost(PlayerSurfaceHost.inline);
  }

  void enterMini() {
    if (state.target == null) return;
    if (state.host == PlayerSurfaceHost.fullscreen) return;
    setHost(PlayerSurfaceHost.mini);
  }

  /// Inline slot left the tree: keep session if still playing → mini.
  ///
  /// Deferred one microtask so a same-frame cid switch can [open] first
  /// without falsely demoting the surface to mini.
  void releaseInline(PlaybackTarget forTarget) {
    Future.microtask(() {
      final t = state.target;
      if (t == null || !t.sameMedia(forTarget)) return;
      if (state.host != PlayerSurfaceHost.inline) return;
      final playing = _adapter?.player.state.playing ?? false;
      if (playing) {
        setHost(PlayerSurfaceHost.mini);
      } else {
        setHost(PlayerSurfaceHost.idle);
      }
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
