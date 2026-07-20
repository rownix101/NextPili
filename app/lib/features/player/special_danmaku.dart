import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Parsed Bilibili mode-7 “高级弹幕” payload (JSON array in `content`).
///
/// Layout matches PiliPlus / canvas_danmaku `SpecialDanmakuContentItem.fromList`:
/// `[startX, startY, "a0-a1", durationSec, text, rotateZ, rotateY, endX, endY,
///  translateDurationMs, translateDelayMs, hasStroke, font?, easing]`.
class SpecialDanmakuSpec {
  const SpecialDanmakuSpec({
    required this.text,
    required this.durationMs,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.startAlpha,
    required this.endAlpha,
    required this.rotateZDeg,
    required this.translateDurationMs,
    required this.translateDelayMs,
    required this.hasStroke,
    required this.easeInCubic,
  });

  final String text;
  final int durationMs;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double startAlpha;
  final double endAlpha;
  final int rotateZDeg;
  final int translateDurationMs;
  final int translateDelayMs;
  final bool hasStroke;
  final bool easeInCubic;

  /// Relative 0–1 coords for video size defaults 1920×1080 (same as PiliPlus).
  static SpecialDanmakuSpec? tryParse(String raw) {
    try {
      final normalized = raw.replaceAll('\n', r'\n');
      final decoded = jsonDecode(normalized);
      if (decoded is! List || decoded.length < 5) return null;
      final list = decoded;

      final (sx, ex) =
          _toRelative(list[0], list.length > 7 ? list[7] : list[0], 1920);
      final (sy, ey) =
          _toRelative(list[1], list.length > 8 ? list[8] : list[1], 1080);

      var startA = 1.0;
      var endA = 1.0;
      if (list.length > 2 && list[2] is String) {
        final parts = (list[2] as String).split('-');
        startA = double.tryParse(parts.first)?.clamp(0.0, 1.0) ?? 1.0;
        endA = double.tryParse(parts.length > 1 ? parts[1] : parts.first)
                ?.clamp(0.0, 1.0) ??
            startA;
      }

      final durationMs = (_asDouble(list[3]) * 1000).round().clamp(200, 60000);
      final text = list[4].toString().trimRight();
      if (text.isEmpty) return null;

      final rotateZ = _asInt(list.length > 5 ? list[5] : 0);
      final translateDurationMs =
          _asInt(list.length > 9 ? list[9] : durationMs).clamp(0, 60000);
      final translateDelayMs =
          _asInt(list.length > 10 ? list[10] : 0).clamp(0, 60000);
      final hasStroke = list.length > 11 && _asInt(list[11]) == 1;
      final easeInCubic = list.length > 13 && _asInt(list[13]) == 1;

      return SpecialDanmakuSpec(
        text: text,
        durationMs: durationMs,
        startX: sx,
        startY: sy,
        endX: ex,
        endY: ey,
        startAlpha: startA,
        endAlpha: endA,
        rotateZDeg: rotateZ,
        translateDurationMs:
            translateDurationMs == 0 ? durationMs : translateDurationMs,
        translateDelayMs: translateDelayMs,
        hasStroke: hasStroke,
        easeInCubic: easeInCubic,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sample position + opacity at [elapsed] into the special lifetime.
  ({double x, double y, double alpha}) sample(
    Duration elapsed, {
    required double width,
    required double height,
  }) {
    final tMs = elapsed.inMilliseconds;
    final life = (tMs / durationMs).clamp(0.0, 1.0);
    final alpha = startAlpha + (endAlpha - startAlpha) * life;

    double dx;
    double dy;
    if (tMs <= translateDelayMs) {
      dx = startX;
      dy = startY;
    } else {
      final raw =
          ((tMs - translateDelayMs) / translateDurationMs).clamp(0.0, 1.0);
      final p = easeInCubic ? Curves.easeInCubic.transform(raw) : raw;
      dx = startX + (endX - startX) * p;
      dy = startY + (endY - startY) * p;
    }
    return (x: dx * width, y: dy * height, alpha: alpha);
  }

  static (double, double) _toRelative(
    dynamic rawStart,
    dynamic rawEnd,
    double videoSize,
  ) {
    double? convert(dynamic digit) {
      if (digit is int) return digit.toDouble();
      if (digit is double) return digit.isFinite ? digit : null;
      if (digit is String) return double.tryParse(digit);
      return null;
    }

    double radix(double? value, dynamic raw) {
      if (value == null) return 0;
      // PiliPlus: absolute if value > 1, or integer-looking string without '.'.
      final absolute =
          value > 1 || (raw is String && !raw.contains('.'));
      return absolute ? value / videoSize : value;
    }

    var start = convert(rawStart);
    var end = convert(rawEnd);
    if (start == null && end == null) return (0, 0);
    start ??= end;
    end ??= start;
    return (radix(start, rawStart), radix(end, rawEnd));
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

double specialRotateRad(int deg) => deg * math.pi / 180.0;
