import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';

/// Thin media_kit adapter over [MediaSourceDto].
class MediaKitPlayerAdapter {
  MediaKitPlayerAdapter() {
    player = Player();
    // Flutter 3.38+ Linux changed EGL ownership; media_kit H/W texture often
    // paints a solid color while audio still plays (media-kit#1321 / #1404).
    // Prefer S/W path on Linux until upstream is solid on current Flutter.
    final linux = defaultTargetPlatform == TargetPlatform.linux;
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !linux,
      ),
    );
  }

  late final Player player;
  late final VideoController controller;

  MediaSourceDto? _source;
  String? _videoId;
  String? _audioId;

  MediaSourceDto? get source => _source;

  StreamDto? get currentVideo {
    final s = _source;
    if (s == null) return null;
    final id = _videoId ?? s.recommendedVideoId;
    for (final v in s.videos) {
      if (v.id == id) return v;
    }
    return s.videos.isEmpty ? null : s.videos.first;
  }

  /// Unique video qualities (by qn) for the quality menu.
  List<StreamDto> get qualityOptions {
    final s = _source;
    if (s == null) return const [];
    final seen = <int>{};
    final out = <StreamDto>[];
    for (final v in s.videos) {
      final q = v.qn;
      if (q != null) {
        if (seen.add(q)) out.add(v);
      } else {
        out.add(v);
      }
    }
    out.sort((a, b) => (b.qn ?? 0).compareTo(a.qn ?? 0));
    return out;
  }

  Future<void> open(MediaSourceDto source) async {
    _source = source;
    _videoId = source.recommendedVideoId;
    _audioId = source.recommendedAudioId.isEmpty
        ? null
        : source.recommendedAudioId;
    await _openCurrent(position: Duration.zero);
  }

  Future<void> setQuality(String streamId) async {
    if (_source == null || _videoId == streamId) return;
    final pos = player.state.position;
    final playing = player.state.playing;
    _videoId = streamId;
    await _openCurrent(position: pos);
    if (playing) {
      await player.play();
    }
  }

  Future<void> _openCurrent({required Duration position}) async {
    final s = _source;
    if (s == null) return;
    final video = currentVideo;
    if (video == null || video.url.isEmpty) {
      throw StateError('no video stream');
    }
    final headers = <String, String>{
      for (final h in s.headers) h.key: h.value,
    };

    StreamDto? audio;
    final audioId = _audioId ?? s.recommendedAudioId;
    if (audioId.isNotEmpty) {
      for (final a in s.audios) {
        if (a.id == audioId) {
          audio = a;
          break;
        }
      }
    }
    if (audio == null && s.audios.isNotEmpty) {
      audio = s.audios.first;
    }

    // CDN often requires Referer on both video and audio (mpv native property).
    final headerFields = headers.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(',');
    await _trySetProperty('http-header-fields', headerFields);

    await player.open(
      Media(video.url, httpHeaders: headers),
      play: true,
    );

    if (audio != null && audio.url.isNotEmpty) {
      try {
        await player.setAudioTrack(
          AudioTrack.uri(audio.url, title: audio.qualityLabel),
        );
      } catch (_) {
        await _trySetProperty('audio-files', audio.url);
      }
    }

    if (position > Duration.zero) {
      await player.seek(position);
    }
  }

  Future<void> _trySetProperty(String name, String value) async {
    final platform = player.platform;
    if (platform == null) return;
    try {
      await (platform as dynamic).setProperty(name, value);
    } catch (_) {}
  }

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> seek(Duration d) => player.seek(d);

  Future<void> dispose() async {
    await player.dispose();
  }
}
