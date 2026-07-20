import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/theme/player_colors.dart';

/// ~6 min segment length (matches Rust `DANMAKU_SEGMENT_MS`).
const int kDanmakuSegmentMs = 6 * 60 * 1000;

/// Max concurrent on-screen danmaku (performance baseline).
const int kDanmakuMaxOnScreen = 48;

/// Display duration for a scrolling item.
const Duration kDanmakuTtl = Duration(milliseconds: 7500);

/// Lightweight overlay: loads segments by position, paints scrolling / top / bottom.
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.aid,
    required this.cid,
    required this.position,
    this.enabled = true,
  });

  final int aid;
  final int cid;
  final Stream<Duration> position;
  final bool enabled;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final Map<int, List<DanmakuItemDto>> _segments = {};
  final Set<int> _loading = {};
  final Set<int> _failed = {};
  final Set<int> _spawnedIds = {};
  final List<_ActiveDanmaku> _active = [];

  StreamSubscription<Duration>? _sub;
  late final AnimationController _tick;
  int _lastSeg = 0;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onTick);
    _tick.repeat();
    _sub = widget.position.listen(_onPosition);
    _ensureSegment(1);
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cid != widget.cid || oldWidget.aid != widget.aid) {
      _segments.clear();
      _loading.clear();
      _failed.clear();
      _spawnedIds.clear();
      _active.clear();
      _lastSeg = 0;
      _ensureSegment(1);
    }
    if (oldWidget.position != widget.position) {
      _sub?.cancel();
      _sub = widget.position.listen(_onPosition);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _onPosition(Duration d) {
    final seg = (d.inMilliseconds ~/ kDanmakuSegmentMs) + 1;
    if (seg != _lastSeg) {
      _lastSeg = seg;
      _ensureSegment(seg);
      // Prefetch next
      _ensureSegment(seg + 1);
    }
    if (!widget.enabled) return;
    _spawnForPosition(d);
  }

  void _onTick() {
    if (!mounted || _active.isEmpty) return;
    final now = DateTime.now();
    _active.removeWhere((a) => now.difference(a.born) > kDanmakuTtl);
    setState(() {});
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
    } catch (_) {
      _failed.add(index);
    } finally {
      _loading.remove(index);
    }
  }

  void _spawnForPosition(Duration pos) {
    final ms = pos.inMilliseconds;
    final seg = (ms ~/ kDanmakuSegmentMs) + 1;
    final items = _segments[seg];
    if (items == null || items.isEmpty) return;

    // Window: items that should start in the last ~80ms
    const window = 80;
    for (final item in items) {
      final p = i64(item.progressMs);
      if (p < ms - window || p > ms) continue;
      final id = i64(item.id);
      final key = id != 0 ? id : Object.hash(p, item.text);
      if (_spawnedIds.contains(key)) continue;
      if (_active.length >= kDanmakuMaxOnScreen) break;
      _spawnedIds.add(key);
      // Bound memory of spawned set
      if (_spawnedIds.length > 8000) {
        _spawnedIds.clear();
      }
      _active.add(
        _ActiveDanmaku(
          item: item,
          born: DateTime.now(),
          lane: _pickLane(item.mode),
        ),
      );
    }
  }

  int _pickLane(int mode) {
    // mode 4 bottom, 5 top, else scroll lanes 0..11
    if (mode == 5) return -1;
    if (mode == 4) return -2;
    return math.Random().nextInt(12);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final colors = PlayerColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final now = DateTime.now();
        return IgnorePointer(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final a in _active)
                _DanmakuLabel(
                  active: a,
                  width: w,
                  height: h,
                  now: now,
                  defaultColor: colors.danmakuDefault,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveDanmaku {
  _ActiveDanmaku({
    required this.item,
    required this.born,
    required this.lane,
  });

  final DanmakuItemDto item;
  final DateTime born;
  /// >=0 scroll lane; -1 top; -2 bottom.
  final int lane;
}

class _DanmakuLabel extends StatelessWidget {
  const _DanmakuLabel({
    required this.active,
    required this.width,
    required this.height,
    required this.now,
    required this.defaultColor,
  });

  final _ActiveDanmaku active;
  final double width;
  final double height;
  final DateTime now;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    final t =
        now.difference(active.born).inMilliseconds / kDanmakuTtl.inMilliseconds;
    final progress = t.clamp(0.0, 1.0);
    final color = _colorOf(active.item.color, defaultColor);
    final fontSize = (active.item.fontsize > 0 ? active.item.fontsize : 25)
        .toDouble()
        .clamp(14.0, 36.0);

    final text = Text(
      active.item.text,
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: TextStyle(
        color: color,
        fontSize: fontSize * 0.72,
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(blurRadius: 2, color: Color(0xCC000000), offset: Offset(1, 1)),
        ],
      ),
    );

    if (active.lane == -1 || active.lane == -2) {
      final top = active.lane == -1
          ? 8.0 + (active.item.text.hashCode.abs() % 3) * (fontSize + 4)
          : height - 48 - (active.item.text.hashCode.abs() % 3) * (fontSize + 4);
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Opacity(
          opacity: (1.0 - (progress - 0.85).clamp(0.0, 0.15) / 0.15),
          child: Center(child: text),
        ),
      );
    }

    // Scroll right → left
    final y = 8.0 + active.lane * (fontSize * 0.9 + 6);
    final travel = width + 280;
    final x = width - progress * travel;
    return Positioned(
      top: y.clamp(0, math.max(0, height - fontSize - 8)),
      left: x,
      child: text,
    );
  }

  Color _colorOf(int rgb, Color fallback) {
    if (rgb == 0) return fallback;
    final r = (rgb >> 16) & 0xff;
    final g = (rgb >> 8) & 0xff;
    final b = rgb & 0xff;
    return Color.fromARGB(0xff, r, g, b);
  }
}
