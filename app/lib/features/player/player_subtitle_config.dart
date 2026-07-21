import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reference canvas used by media_kit's default subtitle scale (1920×1080).
const double kSubtitleScaleRefWidth = 1920.0;
const double kSubtitleScaleRefHeight = 1080.0;

/// Base logical font size before area scale (media_kit default is 32).
///
/// Desktop-first: larger base so inline players stay readable after area
/// shrink; full 1080p surface stays ~48 logical px.
const double kPlayerSubtitleFontSize = 48.0;

/// Floor for area-based scale so small/inline surfaces do not drop below ~half
/// of the reference size (media_kit clamps only the *upper* bound at 1.0).
const double kPlayerSubtitleScaleFloor = 0.55;

/// Default subtitle paint: white text + soft black plate (media_kit style).
const TextStyle kPlayerSubtitleStyle = TextStyle(
  height: 1.35,
  fontSize: kPlayerSubtitleFontSize,
  letterSpacing: 0.0,
  wordSpacing: 0.0,
  color: Color(0xffffffff),
  fontWeight: FontWeight.w500,
  backgroundColor: Color(0xaa000000),
);

/// Area-based scale matching media_kit, with a readability floor for desktop
/// inline / mini surfaces.
double playerSubtitleScaleForSize(Size size) {
  final area = size.width * size.height;
  const ref = kSubtitleScaleRefWidth * kSubtitleScaleRefHeight;
  if (area <= 0 || !area.isFinite) return kPlayerSubtitleScaleFloor;
  final adaptive = math.sqrt((area / ref).clamp(0.0, 1.0));
  return math.max(adaptive, kPlayerSubtitleScaleFloor);
}

/// media_kit [SubtitleViewConfiguration] for the given player surface size.
SubtitleViewConfiguration playerSubtitleViewConfiguration(Size size) {
  final scale = playerSubtitleScaleForSize(size);
  return SubtitleViewConfiguration(
    style: kPlayerSubtitleStyle,
    textScaler: TextScaler.linear(scale),
    // Keep clear of bottom chrome / progress.
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
  );
}
