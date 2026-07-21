import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/playback_session.dart';

/// Regression: related video push/pop must not leave the previous video
/// owning the decoder or the new page stuck without a surface.
///
/// See [releaseInlineNextHost] + [PlaybackSession.open] host re-assert.
void main() {
  group('PlaybackTarget.sameMedia', () {
    test('distinguishes related switch (different videoId)', () {
      const a = PlaybackTarget(videoId: 'BV1aaa', cid: 1);
      const b = PlaybackTarget(videoId: 'BV1bbb', cid: 2);
      expect(a.sameMedia(b), isFalse);
      expect(a.sameMedia(a), isTrue);
    });

    test('distinguishes multi-P (same videoId, different cid)', () {
      const p1 = PlaybackTarget(videoId: 'BV1aaa', cid: 1);
      const p2 = PlaybackTarget(videoId: 'BV1aaa', cid: 2);
      expect(p1.sameMedia(p2), isFalse);
    });

    test('ignores qn so quality switch keeps inline surface ownership', () {
      // Watch-page PlayerPane defaults qn:0; switchQuality writes session qn.
      // sameMedia must still match or ownsSurface drops and Video unmounts.
      const pane = PlaybackTarget(videoId: 'BV1aaa', cid: 1, qn: 0);
      const afterQuality = PlaybackTarget(videoId: 'BV1aaa', cid: 1, qn: 80);
      expect(pane.sameMedia(afterQuality), isTrue);
      expect(afterQuality.sameMedia(pane), isTrue);
    });

    test('distinguishes PGC ep (same cid path, different epId)', () {
      const ugc = PlaybackTarget(videoId: 'ss1', cid: 9, epId: 0);
      const ep = PlaybackTarget(videoId: 'ss1', cid: 9, epId: 42);
      expect(ugc.sameMedia(ep), isFalse);
    });
  });

  group('releaseInlineNextHost', () {
    test('covered by related (preferMini:false) → idle while still playing',
        () {
      final next = releaseInlineNextHost(
        ownsTarget: true,
        host: PlayerSurfaceHost.inline,
        loading: false,
        playing: true,
        preferMini: false,
      );
      expect(next, PlayerSurfaceHost.idle);
    });

    test('leave watch stack while playing (preferMini:true) → mini', () {
      final next = releaseInlineNextHost(
        ownsTarget: true,
        host: PlayerSurfaceHost.inline,
        loading: false,
        playing: true,
        preferMini: true,
      );
      expect(next, PlayerSurfaceHost.mini);
    });

    test('new page already claimed different media → no-op', () {
      final next = releaseInlineNextHost(
        ownsTarget: false,
        host: PlayerSurfaceHost.inline,
        loading: false,
        playing: true,
        preferMini: true,
      );
      expect(next, isNull);
    });

    test('in-flight open (loading) → no-op so open keeps host', () {
      final next = releaseInlineNextHost(
        ownsTarget: true,
        host: PlayerSurfaceHost.inline,
        loading: true,
        playing: true,
        preferMini: true,
      );
      expect(next, isNull);
    });

    test('not playing → idle even if preferMini', () {
      final next = releaseInlineNextHost(
        ownsTarget: true,
        host: PlayerSurfaceHost.inline,
        loading: false,
        playing: false,
        preferMini: true,
      );
      expect(next, PlayerSurfaceHost.idle);
    });

    test('already mini → no-op', () {
      final next = releaseInlineNextHost(
        ownsTarget: true,
        host: PlayerSurfaceHost.mini,
        loading: false,
        playing: true,
        preferMini: true,
      );
      expect(next, isNull);
    });
  });

  group('PlaybackSessionState host reclaim', () {
    test('copyWith can re-assert inline host after mid-flight mini', () {
      // Mirrors open() success path: releaseInline demoted to mini while
      // playurl was in flight; open must restore the requested host.
      const midFlight = PlaybackSessionState(
        target: PlaybackTarget(videoId: 'BV1bbb', cid: 9),
        host: PlayerSurfaceHost.mini,
        loading: true,
      );
      final done = midFlight.copyWith(
        host: PlayerSurfaceHost.inline,
        loading: false,
      );
      expect(done.host, PlayerSurfaceHost.inline);
      expect(done.loading, isFalse);
      expect(done.target?.videoId, 'BV1bbb');
    });
  });
}
