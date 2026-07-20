import 'package:flutter/material.dart';

import 'palette.dart';

/// Player overlay tokens — always dark chrome (design-system §3.5).
@immutable
class PlayerColors extends ThemeExtension<PlayerColors> {
  const PlayerColors({
    required this.scrimTop,
    required this.scrimBottom,
    required this.controlFg,
    required this.controlFgMuted,
    required this.progressPlayed,
    required this.progressBuffered,
    required this.progressTrack,
    required this.danmakuDefault,
    required this.chromeGlass,
  });

  final Color scrimTop;
  final Color scrimBottom;
  final Color controlFg;
  final Color controlFgMuted;
  final Color progressPlayed;
  final Color progressBuffered;
  final Color progressTrack;
  final Color danmakuDefault;
  final Color chromeGlass;

  static const standard = PlayerColors(
    scrimTop: Color(0x00000000),
    scrimBottom: Color(0x99000000),
    controlFg: Color(0xFFF8FAFC),
    controlFgMuted: Color(0xB3F8FAFC),
    progressPlayed: Palette.accentDark,
    progressBuffered: Color(0x66FFFFFF),
    progressTrack: Color(0x33FFFFFF),
    danmakuDefault: Color(0xFFF8FAFC),
    chromeGlass: Palette.glassTintPlayer,
  );

  static PlayerColors of(BuildContext context) {
    return Theme.of(context).extension<PlayerColors>() ?? standard;
  }

  @override
  PlayerColors copyWith({
    Color? scrimTop,
    Color? scrimBottom,
    Color? controlFg,
    Color? controlFgMuted,
    Color? progressPlayed,
    Color? progressBuffered,
    Color? progressTrack,
    Color? danmakuDefault,
    Color? chromeGlass,
  }) {
    return PlayerColors(
      scrimTop: scrimTop ?? this.scrimTop,
      scrimBottom: scrimBottom ?? this.scrimBottom,
      controlFg: controlFg ?? this.controlFg,
      controlFgMuted: controlFgMuted ?? this.controlFgMuted,
      progressPlayed: progressPlayed ?? this.progressPlayed,
      progressBuffered: progressBuffered ?? this.progressBuffered,
      progressTrack: progressTrack ?? this.progressTrack,
      danmakuDefault: danmakuDefault ?? this.danmakuDefault,
      chromeGlass: chromeGlass ?? this.chromeGlass,
    );
  }

  @override
  PlayerColors lerp(ThemeExtension<PlayerColors>? other, double t) {
    if (other is! PlayerColors) return this;
    return PlayerColors(
      scrimTop: Color.lerp(scrimTop, other.scrimTop, t)!,
      scrimBottom: Color.lerp(scrimBottom, other.scrimBottom, t)!,
      controlFg: Color.lerp(controlFg, other.controlFg, t)!,
      controlFgMuted: Color.lerp(controlFgMuted, other.controlFgMuted, t)!,
      progressPlayed: Color.lerp(progressPlayed, other.progressPlayed, t)!,
      progressBuffered: Color.lerp(progressBuffered, other.progressBuffered, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      danmakuDefault: Color.lerp(danmakuDefault, other.danmakuDefault, t)!,
      chromeGlass: Color.lerp(chromeGlass, other.chromeGlass, t)!,
    );
  }
}
