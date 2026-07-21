import 'package:flutter/material.dart';

import 'player_subtitle_config.dart';
import 'subtitle_cues.dart';

/// Flutter-side CC overlay driven by playback position.
///
/// Avoids media_kit `SubtitleTrack.data` / mpv `sub-add`, which can interrupt
/// demuxing and often fails to surface text when the temp file has no `.vtt`
/// extension.
class SubtitleOverlay extends StatelessWidget {
  const SubtitleOverlay({
    super.key,
    required this.position,
    required this.cues,
    this.initialPosition = Duration.zero,
  });

  final Stream<Duration> position;
  final List<SubtitleCue> cues;
  final Duration initialPosition;

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = playerSubtitleScaleForSize(constraints.biggest);
        final fontSize = kPlayerSubtitleFontSize * scale;
        final padBottom = (40.0 * scale).clamp(24.0, 56.0);

        return StreamBuilder<Duration>(
          stream: position,
          initialData: initialPosition,
          builder: (context, snap) {
            final t = snap.data ?? initialPosition;
            final active = cuesAt(cues, t);
            if (active.isEmpty) return const SizedBox.shrink();

            // Prefer bottom cues; if mixed, group by align.
            final byAlign = <SubtitleAlign, List<SubtitleCue>>{};
            for (final c in active) {
              byAlign.putIfAbsent(c.align, () => []).add(c);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                for (final entry in byAlign.entries)
                  _AlignedBlock(
                    align: entry.key,
                    texts: [for (final c in entry.value) c.text],
                    fontSize: fontSize,
                    padBottom: padBottom,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AlignedBlock extends StatelessWidget {
  const _AlignedBlock({
    required this.align,
    required this.texts,
    required this.fontSize,
    required this.padBottom,
  });

  final SubtitleAlign align;
  final List<String> texts;
  final double fontSize;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (align) {
      SubtitleAlign.top => Alignment.topCenter,
      SubtitleAlign.center => Alignment.center,
      SubtitleAlign.bottom => Alignment.bottomCenter,
    };
    final padding = switch (align) {
      SubtitleAlign.top => const EdgeInsets.fromLTRB(16, 24, 16, 0),
      SubtitleAlign.center => const EdgeInsets.symmetric(horizontal: 16),
      SubtitleAlign.bottom => EdgeInsets.fromLTRB(16, 0, 16, padBottom),
    };

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: IgnorePointer(
          child: Text(
            texts.join('\n'),
            textAlign: TextAlign.center,
            style: kPlayerSubtitleStyle.copyWith(fontSize: fontSize),
          ),
        ),
      ),
    );
  }
}
