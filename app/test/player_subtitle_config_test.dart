import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/player_subtitle_config.dart';

void main() {
  group('playerSubtitleScaleForSize', () {
    test('full reference surface is 1.0', () {
      expect(
        playerSubtitleScaleForSize(
          const Size(kSubtitleScaleRefWidth, kSubtitleScaleRefHeight),
        ),
        1.0,
      );
    });

    test('small surfaces clamp to floor', () {
      final mini = playerSubtitleScaleForSize(const Size(320, 180));
      expect(mini, kPlayerSubtitleScaleFloor);
    });

    test('mid inline is at least the floor', () {
      final mid = playerSubtitleScaleForSize(const Size(960, 540));
      expect(mid, greaterThanOrEqualTo(kPlayerSubtitleScaleFloor));
      expect(mid, lessThanOrEqualTo(1.0));
    });
  });

  test('config uses larger base font and custom scaler', () {
    final cfg = playerSubtitleViewConfiguration(const Size(960, 540));
    expect(cfg.style.fontSize, kPlayerSubtitleFontSize);
    expect(cfg.textScaler, isNotNull);
    expect(cfg.textScaler!.scale(kPlayerSubtitleFontSize), greaterThan(20));
  });
}
