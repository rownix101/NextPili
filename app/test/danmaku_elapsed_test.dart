import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/danmaku_overlay.dart';

void main() {
  group('advanceDanmakuElapsed', () {
    test('advances only while playing', () {
      const base = Duration(milliseconds: 1000);
      const step = Duration(milliseconds: 16);
      expect(
        advanceDanmakuElapsed(base, step, playing: true),
        const Duration(milliseconds: 1016),
      );
      expect(
        advanceDanmakuElapsed(base, step, playing: false),
        base,
      );
    });

    test('ignores non-positive delta', () {
      const base = Duration(milliseconds: 500);
      expect(
        advanceDanmakuElapsed(base, Duration.zero, playing: true),
        base,
      );
      expect(
        advanceDanmakuElapsed(
          base,
          const Duration(milliseconds: -5),
          playing: true,
        ),
        base,
      );
    });

    test('progress freezes across pause wall time', () {
      var elapsed = Duration.zero;
      elapsed = advanceDanmakuElapsed(
        elapsed,
        const Duration(milliseconds: 2000),
        playing: true,
      );
      final frozen = elapsed;
      // Simulate wall clock continuing while paused.
      elapsed = advanceDanmakuElapsed(
        elapsed,
        const Duration(milliseconds: 5000),
        playing: false,
      );
      expect(elapsed, frozen);
      elapsed = advanceDanmakuElapsed(
        elapsed,
        const Duration(milliseconds: 100),
        playing: true,
      );
      expect(elapsed, const Duration(milliseconds: 2100));
    });

    test('playback rate scales elapsed', () {
      const base = Duration(milliseconds: 1000);
      const step = Duration(milliseconds: 100);
      expect(
        advanceDanmakuElapsed(base, step, playing: true, rate: 2.0),
        const Duration(milliseconds: 1200),
      );
      expect(
        advanceDanmakuElapsed(base, step, playing: true, rate: 0.5),
        const Duration(milliseconds: 1050),
      );
    });
  });

  group('danmakuBucket', () {
    test('100ms buckets match PiliPlus progress~/100', () {
      expect(danmakuBucket(0), 0);
      expect(danmakuBucket(99), 0);
      expect(danmakuBucket(100), 1);
      expect(danmakuBucket(1250), 12);
    });
  });
}
