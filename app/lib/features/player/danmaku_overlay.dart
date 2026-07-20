import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/theme/player_colors.dart';
import 'special_danmaku.dart';

/// ~6 min segment length (matches Rust `DANMAKU_SEGMENT_MS`).
const int kDanmakuSegmentMs = 6 * 60 * 1000;

/// PiliPlus-style time bucket: one list per 100ms of progress.
const int kDanmakuBucketMs = 100;

/// Max concurrent on-screen danmaku (performance baseline).
const int kDanmakuMaxOnScreen = 48;

/// Scroll track count (area ≈ upper 60% of player height via [kDanmakuArea]).
const int kDanmakuScrollLanes = 12;

/// Display area fraction of player height for scroll danmaku.
const double kDanmakuArea = 0.65;

/// Base display duration for a scrolling item at 1x playback rate.
const Duration kDanmakuTtl = Duration(milliseconds: 7500);

/// Top / bottom static duration at 1x.
const Duration kDanmakuStaticTtl = Duration(milliseconds: 4500);

/// Seek jump larger than this clears on-screen + spawn bookkeeping.
const int kDanmakuSeekResetMs = 1000;

/// Advances on-screen elapsed only while playback is running.
///
/// Pure helper so pause freeze behavior can be unit-tested without media_kit.
Duration advanceDanmakuElapsed(
  Duration current,
  Duration delta, {
  required bool playing,
  double rate = 1.0,
}) {
  if (!playing || delta <= Duration.zero) return current;
  final scale = rate <= 0 ? 1.0 : rate;
  final scaledMs = (delta.inMilliseconds * scale).round();
  if (scaledMs <= 0) return current;
  return current + Duration(milliseconds: scaledMs);
}

int danmakuBucket(int progressMs) => progressMs ~/ kDanmakuBucketMs;

/// Lightweight overlay: loads segments by position, paints scrolling / top / bottom.
///
/// Motion is driven by **playback time**, not wall clock: pause freezes on-screen
/// items; resume continues from the same progress. Indexing and seek behavior
/// follow PiliPlus `PlDanmakuController` / `PlDanmaku`.
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.aid,
    required this.cid,
    required this.position,
    required this.playing,
    this.initialPlaying = true,
    this.enabled = true,
    this.opacity = 1.0,
    this.playbackRate = 1.0,
    this.blockColorful = false,
    this.onDanmakuLongPress,
  });

  final int aid;
  final int cid;
  final Stream<Duration> position;

  /// When false, active danmaku freeze (no scroll / fade advance).
  final Stream<bool> playing;

  /// Seed before the first [playing] event (streams may not re-emit current).
  final bool initialPlaying;
  final bool enabled;

  /// 0–1 overlay opacity (PiliPlus `danmakuOpacity`).
  final double opacity;

  /// media_kit rate; shortens TTL so visual speed tracks playback.
  final double playbackRate;

  /// Force white for non-white colors (PiliPlus `blockColorful`).
  final bool blockColorful;

  /// Long-press a danmaku (like / report). Empty space does not absorb taps.
  final ValueChanged<DanmakuItemDto>? onDanmakuLongPress;

  @override
  State<DanmakuOverlay> createState() => DanmakuOverlayState();
}

class DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  /// segment_index → raw items (also used to rebuild buckets).
  final Map<int, List<DanmakuItemDto>> _segments = {};

  /// progress~/100 → items (PiliPlus `_dmSegMap`).
  final Map<int, List<DanmakuItemDto>> _buckets = {};

  final Set<int> _loading = {};
  final Set<int> _failed = {};
  final Set<int> _spawnedIds = {};
  final List<_ActiveDanmaku> _active = [];

  /// Media position (ms) when each lane becomes free again.
  final List<int> _scrollLaneFreeAtMs = List.filled(kDanmakuScrollLanes, 0);
  final List<int> _topLaneFreeAtMs = List.filled(3, 0);
  final List<int> _bottomLaneFreeAtMs = List.filled(3, 0);

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  late final AnimationController _tick;
  int _lastSeg = 0;
  int _lastBucket = -1;
  int _lastPosMs = 0;
  late bool _playing;
  DateTime? _lastTickAt;

  @override
  void initState() {
    super.initState();
    _playing = widget.initialPlaying;
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onTick);
    if (_playing) {
      _tick.repeat();
    }
    _posSub = widget.position.listen(_onPosition);
    _playingSub = widget.playing.listen(_onPlaying);
    _ensureSegment(1);
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cid != widget.cid || oldWidget.aid != widget.aid) {
      _resetAll();
      _ensureSegment(1);
    }
    if (oldWidget.position != widget.position) {
      _posSub?.cancel();
      _posSub = widget.position.listen(_onPosition);
    }
    if (oldWidget.playing != widget.playing) {
      _playingSub?.cancel();
      _playingSub = widget.playing.listen(_onPlaying);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playingSub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _resetAll() {
    _segments.clear();
    _buckets.clear();
    _loading.clear();
    _failed.clear();
    _clearOnScreen();
    _lastSeg = 0;
    _lastBucket = -1;
    _lastPosMs = 0;
    _lastTickAt = null;
  }

  void _clearOnScreen() {
    _spawnedIds.clear();
    _active.clear();
    for (var i = 0; i < _scrollLaneFreeAtMs.length; i++) {
      _scrollLaneFreeAtMs[i] = 0;
    }
    for (var i = 0; i < _topLaneFreeAtMs.length; i++) {
      _topLaneFreeAtMs[i] = 0;
    }
    for (var i = 0; i < _bottomLaneFreeAtMs.length; i++) {
      _bottomLaneFreeAtMs[i] = 0;
    }
  }

  /// Immediately show a locally posted danmaku (optimistic).
  void injectLocal(DanmakuItemDto item) {
    if (!mounted || !widget.enabled) return;
    final id = i64(item.id);
    final p = i64(item.progressMs);
    final key = id != 0 ? id : Object.hash(p, item.text);
    _spawnedIds.add(key);
    final atMs = _lastPosMs > 0 ? _lastPosMs : p;
    final lane = _pickLane(item.mode, atMs: atMs, preferFirst: true);
    _active.add(
      _ActiveDanmaku(
        item: item,
        lane: lane == _laneRejected ? 0 : lane,
        selfSend: true,
      ),
    );
    setState(() {});
  }

  void _onPlaying(bool playing) {
    if (playing == _playing) return;
    _playing = playing;
    // Drop frame delta so resume does not swallow pause duration in one step.
    _lastTickAt = null;
    if (!playing) {
      _tick.stop();
    } else if (!_tick.isAnimating) {
      _tick.repeat();
    }
  }

  void _onPosition(Duration d) {
    final ms = d.inMilliseconds;
    final jump = (ms - _lastPosMs).abs();
    if (_lastPosMs > 0 && jump >= kDanmakuSeekResetMs) {
      // Large seek: drop on-screen and allow re-spawn at new position.
      _clearOnScreen();
      _lastBucket = -1;
      _lastTickAt = null;
    }
    _lastPosMs = ms;

    final seg = (ms ~/ kDanmakuSegmentMs) + 1;
    if (seg != _lastSeg) {
      _lastSeg = seg;
      _ensureSegment(seg);
      _ensureSegment(seg + 1);
    }
    if (!widget.enabled || !_playing) return;
    _spawnForPosition(ms);
  }

  void _onTick() {
    if (!mounted || !_playing || _active.isEmpty) return;
    final now = DateTime.now();
    final last = _lastTickAt ?? now;
    final delta = now.difference(last);
    _lastTickAt = now;
    if (delta <= Duration.zero) return;
    final rate = widget.playbackRate;
    for (final a in _active) {
      a.elapsed = advanceDanmakuElapsed(
        a.elapsed,
        delta,
        playing: _playing,
        rate: rate,
      );
    }
    final scrollTtl = _ttlFor(scroll: true);
    final staticTtl = _ttlFor(scroll: false);
    _active.removeWhere((a) {
      if (a.special != null) {
        return a.elapsed.inMilliseconds >= a.special!.durationMs;
      }
      final ttl = a.isStatic ? staticTtl : scrollTtl;
      return a.elapsed >= ttl;
    });
    setState(() {});
  }

  Duration _ttlFor({required bool scroll}) {
    final base = scroll ? kDanmakuTtl : kDanmakuStaticTtl;
    // Rate is already applied to elapsed; keep base TTL constant in "playback time".
    return base;
  }

  Future<void> _ensureSegment(int index) async {
    if (index < 1) return;
    if (_segments.containsKey(index) ||
        _loading.contains(index) ||
        _failed.contains(index)) {
      return;
    }
    _loading.add(index);
    try {
      final seg = await CoreApi.instance.danmakuSegments(
        aid: widget.aid,
        cid: widget.cid,
        segmentIndex: index,
      );
      if (!mounted) return;
      _segments[index] = seg.items;
      _indexItems(seg.items);
    } catch (_) {
      // Soft-fail; allow retry later by not permanently blocking (timeout only).
      _failed.add(index);
      // Retry once after short delay.
      Future<void>.delayed(const Duration(seconds: 3), () {
        _failed.remove(index);
      });
    } finally {
      _loading.remove(index);
    }
  }

  void _indexItems(List<DanmakuItemDto> items) {
    for (final item in items) {
      final p = i64(item.progressMs);
      final b = danmakuBucket(p);
      (_buckets[b] ??= []).add(item);
    }
  }

  void _spawnForPosition(int ms) {
    // Align to 100ms bucket (PiliPlus).
    final bucket = danmakuBucket(ms);
    if (bucket == _lastBucket) return;
    // Catch up at most a few buckets after lag so we do not flood.
    final from = _lastBucket < 0 ? bucket : math.min(_lastBucket + 1, bucket);
    _lastBucket = bucket;

    for (var b = from; b <= bucket; b++) {
      final list = _buckets[b];
      if (list == null || list.isEmpty) continue;
      for (final item in list) {
        if (_active.length >= kDanmakuMaxOnScreen) return;
        final id = i64(item.id);
        final p = i64(item.progressMs);
        final key = id != 0 ? id : Object.hash(p, item.text);
        if (_spawnedIds.contains(key)) continue;
        _spawnedIds.add(key);
        if (_spawnedIds.length > 8000) {
          _spawnedIds.clear();
        }
        // mode 7: 高级弹幕 (positioned / animated special).
        SpecialDanmakuSpec? special;
        if (item.mode == 7) {
          special = SpecialDanmakuSpec.tryParse(item.text);
        }
        if (special != null) {
          _active.add(
            _ActiveDanmaku(
              item: item,
              lane: -30,
              special: special,
            ),
          );
          continue;
        }
        final lane = _pickLane(item.mode, atMs: ms);
        if (lane == _laneRejected) continue;
        _active.add(
          _ActiveDanmaku(
            item: item,
            lane: lane,
          ),
        );
      }
    }
  }

  static const int _laneRejected = -99;

  int _pickLane(int mode, {required int atMs, bool preferFirst = false}) {
    // mode 4 bottom, 5 top, 7 special handled above, else scroll.
    if (mode == 5) {
      return _reserveStaticLane(_topLaneFreeAtMs, atMs: atMs, base: -1) ??
          (preferFirst ? -10 : _laneRejected);
    }
    if (mode == 4) {
      return _reserveStaticLane(_bottomLaneFreeAtMs, atMs: atMs, base: -2) ??
          (preferFirst ? -20 : _laneRejected);
    }
    // Unparseable mode 7 falls through as scroll.
    // Scroll: first free lane; drop under density unless preferFirst.
    var best = -1;
    for (var i = 0; i < kDanmakuScrollLanes; i++) {
      if (_scrollLaneFreeAtMs[i] <= atMs) {
        best = i;
        break;
      }
    }
    if (best < 0) {
      if (!preferFirst) return _laneRejected;
      best = 0;
    }
    // Reserve ~45% of scroll TTL so tracks do not stack (rough collision).
    final holdMs = (kDanmakuTtl.inMilliseconds * 0.45).round();
    _scrollLaneFreeAtMs[best] = atMs + holdMs;
    return best;
  }

  /// Top `-10-i` / bottom `-20-i` stack slots.
  int? _reserveStaticLane(
    List<int> lanes, {
    required int atMs,
    required int base,
  }) {
    final holdMs = (kDanmakuStaticTtl.inMilliseconds * 0.9).round();
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] <= atMs) {
        lanes[i] = atMs + holdMs;
        if (base == -1) return -10 - i;
        return -20 - i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final colors = PlayerColors.of(context);
    final opacity = widget.opacity.clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 0 || h <= 0) return const SizedBox.shrink();

          // No IgnorePointer: only Positioned labels hit-test (long-press like/report).
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final a in _active)
                _DanmakuLabel(
                  active: a,
                  width: w,
                  height: h,
                  defaultColor: colors.danmakuDefault,
                  blockColorful: widget.blockColorful,
                  scrollTtl: _ttlFor(scroll: true),
                  staticTtl: _ttlFor(scroll: false),
                  onLongPress: widget.onDanmakuLongPress == null
                      ? null
                      : () => widget.onDanmakuLongPress!(a.item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveDanmaku {
  _ActiveDanmaku({
    required this.item,
    required this.lane,
    this.selfSend = false,
    this.special,
  });

  final DanmakuItemDto item;

  /// Time advanced only while playback is running (scaled by rate).
  Duration elapsed = Duration.zero;

  /// >=0 scroll; -10..-12 top; -20..-22 bottom; -30 special (mode 7).
  final int lane;
  final bool selfSend;
  final SpecialDanmakuSpec? special;

  bool get isStatic => lane <= -10 && lane > -30;
  bool get isSpecial => special != null || lane == -30;
}

class _DanmakuLabel extends StatelessWidget {
  const _DanmakuLabel({
    required this.active,
    required this.width,
    required this.height,
    required this.defaultColor,
    required this.blockColorful,
    required this.scrollTtl,
    required this.staticTtl,
    this.onLongPress,
  });

  final _ActiveDanmaku active;
  final double width;
  final double height;
  final Color defaultColor;
  final bool blockColorful;
  final Duration scrollTtl;
  final Duration staticTtl;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(active.item.color, defaultColor);
    final fontSize = (active.item.fontsize > 0 ? active.item.fontsize : 25)
        .toDouble()
        .clamp(14.0, 36.0);
    final displaySize = fontSize * 0.72;

    if (active.special != null) {
      return _buildSpecial(color, displaySize);
    }

    final isStatic = active.isStatic;
    final ttl = isStatic ? staticTtl : scrollTtl;
    final t = active.elapsed.inMilliseconds / ttl.inMilliseconds;
    final progress = t.clamp(0.0, 1.0);

    final text = _styledText(
      active.special?.text ?? active.item.text,
      color: color,
      fontSize: displaySize,
      stroke: true,
    );

    if (isStatic) {
      final stack = active.lane <= -20
          ? (-20 - active.lane)
          : (-10 - active.lane);
      final top = active.lane <= -20
          ? height - 48 - stack * (displaySize + 4)
          : 8.0 + stack * (displaySize + 4);
      return Positioned(
        top: top.clamp(0.0, math.max(0.0, height - displaySize - 4)),
        left: 0,
        right: 0,
        child: Opacity(
          opacity: (1.0 - (progress - 0.8).clamp(0.0, 0.2) / 0.2),
          child: Center(child: _wrapGesture(text)),
        ),
      );
    }

    final areaH = height * kDanmakuArea;
    final laneH = areaH / kDanmakuScrollLanes;
    final y = 4.0 + active.lane * laneH;
    final travel = width + 320;
    final x = width - progress * travel;
    return Positioned(
      top: y.clamp(0.0, math.max(0.0, height - displaySize - 8)),
      left: x,
      child: _wrapGesture(text),
    );
  }

  Widget _buildSpecial(Color color, double displaySize) {
    final spec = active.special!;
    final sample = spec.sample(
      active.elapsed,
      width: width,
      height: height,
    );
    final text = _styledText(
      spec.text,
      color: color.withValues(alpha: sample.alpha.clamp(0.0, 1.0)),
      fontSize: displaySize,
      stroke: spec.hasStroke,
    );
    return Positioned(
      left: sample.x,
      top: sample.y,
      child: Transform.rotate(
        angle: specialRotateRad(spec.rotateZDeg),
        alignment: Alignment.topLeft,
        child: _wrapGesture(text),
      ),
    );
  }

  Widget _wrapGesture(Widget child) {
    if (onLongPress == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      child: child,
    );
  }

  Widget _styledText(
    String content, {
    required Color color,
    required double fontSize,
    required bool stroke,
  }) {
    return Text(
      content,
      maxLines: 4,
      overflow: TextOverflow.visible,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: active.selfSend ? FontWeight.w700 : FontWeight.w600,
        shadows: stroke
            ? const [
                Shadow(
                    blurRadius: 0,
                    color: Color(0xFF000000),
                    offset: Offset(1, 0)),
                Shadow(
                    blurRadius: 0,
                    color: Color(0xFF000000),
                    offset: Offset(-1, 0)),
                Shadow(
                    blurRadius: 0,
                    color: Color(0xFF000000),
                    offset: Offset(0, 1)),
                Shadow(
                    blurRadius: 0,
                    color: Color(0xFF000000),
                    offset: Offset(0, -1)),
                Shadow(
                    blurRadius: 2,
                    color: Color(0x99000000),
                    offset: Offset(1, 1)),
              ]
            : null,
      ),
    );
  }

  Color _colorOf(int rgb, Color fallback) {
    if (rgb == 0) return fallback;
    if (blockColorful && rgb != 0xffffff && rgb != 0x00ffffff) {
      return fallback;
    }
    final r = (rgb >> 16) & 0xff;
    final g = (rgb >> 8) & 0xff;
    final b = rgb & 0xff;
    return Color.fromARGB(0xff, r, g, b);
  }
}
