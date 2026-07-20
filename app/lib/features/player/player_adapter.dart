import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';

/// Thin media_kit adapter over [MediaSourceDto] — design/media §5.
class MediaKitPlayerAdapter {
  MediaKitPlayerAdapter() {
    player = Player();
    // Hardware decode on all platforms (incl. Linux). If you get audio-only /
    // solid-color video on Linux (media-kit#1321 / #1404), fall back by setting
    // enableHardwareAcceleration: false.
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
  }

  late final Player player;
  late final VideoController controller;

  MediaSourceDto? _source;
  String? _videoId;
  String? _audioId;
  String? _subtitleId;
  String? _subtitleVtt;
  String? _subtitleTitle;
  String? _subtitleLang;
  double _rate = 1.0;

  MediaSourceDto? get source => _source;
  double get rate => _rate;
  String? get subtitleId => _subtitleId;

  StreamDto? get currentVideo {
    final s = _source;
    if (s == null) return null;
    final id = _videoId ?? s.recommendedVideoId;
    for (final v in s.videos) {
      if (v.id == id) return v;
    }
    return s.videos.isEmpty ? null : s.videos.first;
  }

  StreamDto? get currentAudio {
    final s = _source;
    if (s == null) return null;
    final id = _audioId ?? s.recommendedAudioId;
    for (final a in s.audios) {
      if (a.id == id) return a;
    }
    return s.audios.isEmpty ? null : s.audios.first;
  }

  SubtitleTrackDto? get currentSubtitle {
    final s = _source;
    final id = _subtitleId;
    if (s == null || id == null || id.isEmpty) return null;
    for (final t in s.subtitles) {
      if (t.id == id) return t;
    }
    return null;
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

  /// Audio menu: standard ladder (192K/132K/64K…) + Dolby/Hi-Res only when present.
  ///
  /// Ordered standard high→low, then Dolby, then Hi-Res. One entry per audio qn.
  List<StreamDto> get audioOptions {
    final s = _source;
    if (s == null || s.audios.isEmpty) return const [];
    final byQn = <int, StreamDto>{};
    final noQn = <StreamDto>[];
    for (final a in s.audios) {
      final q = a.qn;
      if (q != null) {
        final prev = byQn[q];
        if (prev == null || a.bandwidth > prev.bandwidth) {
          byQn[q] = a;
        }
      } else {
        noQn.add(a);
      }
    }
    int roleOrder(String? role) {
      switch (role) {
        case 'dolby':
          return 1;
        case 'hires':
          return 2;
        default:
          return 0; // standard
      }
    }

    int standardRank(StreamDto a) {
      switch (a.qn) {
        case 30280:
          return 192000;
        case 30232:
          return 132000;
        case 30216:
          return 64000;
        default:
          return a.bandwidth;
      }
    }

    final out = [...byQn.values, ...noQn];
    out.sort((a, b) {
      final ro = roleOrder(a.role).compareTo(roleOrder(b.role));
      if (ro != 0) return ro;
      return standardRank(b).compareTo(standardRank(a));
    });
    return List<StreamDto>.unmodifiable(out);
  }

  List<SubtitleTrackDto> get subtitleOptions =>
      List<SubtitleTrackDto>.unmodifiable(_source?.subtitles ?? const []);

  static const List<double> speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  Future<void> open(MediaSourceDto source) async {
    _source = source;
    _videoId = source.recommendedVideoId;
    _audioId = source.recommendedAudioId.isEmpty
        ? null
        : source.recommendedAudioId;
    // Fresh source — drop external subtitle session.
    _subtitleId = null;
    _subtitleVtt = null;
    _subtitleTitle = null;
    _subtitleLang = null;
    await _openCurrent(position: Duration.zero, restoreSubtitle: false);
  }

  Future<void> setQuality(String streamId) async {
    if (_source == null || _videoId == streamId) return;
    final pos = player.state.position;
    final playing = player.state.playing;
    _videoId = streamId;
    await _openCurrent(position: pos, restoreSubtitle: true);
    if (playing) {
      await player.play();
    }
  }

  Future<void> setAudio(String streamId) async {
    if (_source == null || _audioId == streamId) return;
    final pos = player.state.position;
    final playing = player.state.playing;
    _audioId = streamId;
    await _openCurrent(position: pos, restoreSubtitle: true);
    if (playing) {
      await player.play();
    }
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    await player.setRate(rate);
  }

  /// Load external WebVTT data, or clear when [id]/[vtt] empty.
  Future<void> setSubtitle({
    String? id,
    String? vtt,
    String? title,
    String? language,
  }) async {
    if (id == null || id.isEmpty || vtt == null || vtt.isEmpty) {
      _subtitleId = null;
      _subtitleVtt = null;
      _subtitleTitle = null;
      _subtitleLang = null;
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    _subtitleId = id;
    _subtitleVtt = vtt;
    _subtitleTitle = title;
    _subtitleLang = language;
    await player.setSubtitleTrack(
      SubtitleTrack.data(
        vtt,
        title: title,
        language: language,
      ),
    );
  }

  Future<void> _openCurrent({
    required Duration position,
    required bool restoreSubtitle,
  }) async {
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
          AudioTrack.uri(
            audio.url,
            title: audio.qualityLabel,
            language: audio.language,
          ),
        );
      } catch (_) {
        await _trySetProperty('audio-files', audio.url);
      }
    }

    if (_rate != 1.0) {
      await player.setRate(_rate);
    }

    if (restoreSubtitle &&
        _subtitleId != null &&
        _subtitleVtt != null &&
        _subtitleVtt!.isNotEmpty) {
      await player.setSubtitleTrack(
        SubtitleTrack.data(
          _subtitleVtt!,
          title: _subtitleTitle,
          language: _subtitleLang,
        ),
      );
    } else {
      await player.setSubtitleTrack(SubtitleTrack.no());
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
