import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/special_danmaku.dart';

void main() {
  group('SpecialDanmakuSpec.tryParse', () {
    test('parses positioned special array', () {
      // Minimal mode-7 payload (PiliPlus / bilibili advanced danmaku).
      const raw =
          r'''[0.1,0.2,"1-0",3.5,"hello",0,0,0.8,0.6,2000,100,1,"SimHei",0]''';
      final spec = SpecialDanmakuSpec.tryParse(raw);
      expect(spec, isNotNull);
      expect(spec!.text, 'hello');
      expect(spec.durationMs, 3500);
      expect(spec.startX, closeTo(0.1, 1e-6));
      expect(spec.startY, closeTo(0.2, 1e-6));
      expect(spec.endX, closeTo(0.8, 1e-6));
      expect(spec.endY, closeTo(0.6, 1e-6));
      expect(spec.startAlpha, 1.0);
      expect(spec.endAlpha, 0.0);
      expect(spec.hasStroke, isTrue);
      expect(spec.translateDelayMs, 100);
    });

    test('absolute coords normalize by 1920x1080', () {
      const raw = r'''[960,540,"1-1",1,"mid",0,0,960,540,1000,0,0,"",0]''';
      final spec = SpecialDanmakuSpec.tryParse(raw);
      expect(spec, isNotNull);
      expect(spec!.startX, closeTo(0.5, 1e-6));
      expect(spec.startY, closeTo(0.5, 1e-6));
    });

    test('rejects invalid payload', () {
      expect(SpecialDanmakuSpec.tryParse('not json'), isNull);
      expect(SpecialDanmakuSpec.tryParse('[]'), isNull);
      expect(SpecialDanmakuSpec.tryParse('[1,2,3]'), isNull);
    });

    test('samples position over time', () {
      const raw = r'''[0,0,"1-1",2,"x",0,0,1,1,2000,0,0,"",0]''';
      final spec = SpecialDanmakuSpec.tryParse(raw)!;
      final mid = spec.sample(
        const Duration(milliseconds: 1000),
        width: 100,
        height: 100,
      );
      expect(mid.x, closeTo(50, 1e-3));
      expect(mid.y, closeTo(50, 1e-3));
    });
  });
}
