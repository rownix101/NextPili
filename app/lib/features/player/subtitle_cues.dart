/// One timed subtitle cue (WebVTT body line).
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
    this.align = SubtitleAlign.bottom,
  });

  final Duration start;
  final Duration end;
  final String text;
  final SubtitleAlign align;

  bool activeAt(Duration t) => t >= start && t < end;
}

enum SubtitleAlign { top, center, bottom }

/// Parse WebVTT produced by Rust `bilibili_json_to_vtt` (and plain WEBVTT).
///
/// Tolerant of optional cue ids, settings after `-->`, multi-line text.
List<SubtitleCue> parseWebVtt(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return const [];

  final lines = text.split('\n');
  // Skip WEBVTT header + optional metadata until blank line.
  var i = 0;
  if (lines.isNotEmpty && lines.first.toUpperCase().startsWith('WEBVTT')) {
    i = 1;
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      i++;
    }
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
  }

  final cues = <SubtitleCue>[];
  while (i < lines.length) {
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) break;

    // Optional numeric / string cue id.
    var line = lines[i].trim();
    if (!line.contains('-->') && i + 1 < lines.length) {
      i++;
      if (i >= lines.length) break;
      line = lines[i].trim();
    }

    final arrow = line.indexOf('-->');
    if (arrow < 0) {
      i++;
      continue;
    }
    final startRaw = line.substring(0, arrow).trim();
    final rest = line.substring(arrow + 3).trim();
    final parts = rest.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      i++;
      continue;
    }
    final endRaw = parts.first;
    final settings = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final start = _parseVttTs(startRaw);
    final end = _parseVttTs(endRaw);
    i++;

    final body = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      body.add(lines[i]);
      i++;
    }
    final content = body
        .join('\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    if (start == null || end == null || content.isEmpty || end <= start) {
      continue;
    }
    cues.add(
      SubtitleCue(
        start: start,
        end: end,
        text: content,
        align: _alignFromSettings(settings),
      ),
    );
  }
  return cues;
}

/// Active cues at [t] (usually 0–1 for B 站).
List<SubtitleCue> cuesAt(List<SubtitleCue> cues, Duration t) {
  if (cues.isEmpty) return const [];
  // Linear scan is fine for typical B 站 tracks (hundreds of cues).
  return [
    for (final c in cues)
      if (c.activeAt(t)) c,
  ];
}

SubtitleAlign _alignFromSettings(String settings) {
  // B 站 / our exporter: line:88% bottom · line:8% top · line:50% center.
  final m = RegExp(r'line:(\d+(?:\.\d+)?)%').firstMatch(settings);
  if (m != null) {
    final pct = double.tryParse(m.group(1)!) ?? 88;
    if (pct <= 25) return SubtitleAlign.top;
    if (pct >= 70) return SubtitleAlign.bottom;
    return SubtitleAlign.center;
  }
  if (settings.contains('line:0') || settings.contains('align:start')) {
    return SubtitleAlign.top;
  }
  return SubtitleAlign.bottom;
}

Duration? _parseVttTs(String raw) {
  // HH:MM:SS.mmm or MM:SS.mmm
  final cleaned = raw.trim();
  final parts = cleaned.split(':');
  if (parts.length < 2 || parts.length > 3) return null;

  double secPart;
  int h = 0;
  int m;
  if (parts.length == 3) {
    h = int.tryParse(parts[0]) ?? -1;
    m = int.tryParse(parts[1]) ?? -1;
    secPart = double.tryParse(parts[2]) ?? -1;
  } else {
    m = int.tryParse(parts[0]) ?? -1;
    secPart = double.tryParse(parts[1]) ?? -1;
  }
  if (h < 0 || m < 0 || secPart < 0) return null;
  final whole = secPart.floor();
  final ms = ((secPart - whole) * 1000).round();
  return Duration(
    hours: h,
    minutes: m,
    seconds: whole,
    milliseconds: ms,
  );
}
