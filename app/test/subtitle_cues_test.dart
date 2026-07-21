import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/subtitle_cues.dart';

void main() {
  group('parseWebVtt', () {
    test('parses Rust bilibili_json_to_vtt shape', () {
      const vtt = '''WEBVTT

1
00:00:01.500 --> 00:00:03.250 line:88% position:50% align:center
你好

2
00:00:04.000 --> 00:00:05.000 line:88% position:50% align:center
world
''';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(2));
      expect(cues[0].text, '你好');
      expect(cues[0].start, const Duration(milliseconds: 1500));
      expect(cues[0].end, const Duration(milliseconds: 3250));
      expect(cues[0].align, SubtitleAlign.bottom);
      expect(cues[1].text, 'world');
    });

    test('top location maps to SubtitleAlign.top', () {
      const vtt = '''WEBVTT

1
00:00:00.000 --> 00:00:01.000 line:8% position:50% align:center
TOP
''';
      final cues = parseWebVtt(vtt);
      expect(cues.single.align, SubtitleAlign.top);
    });

    test('cuesAt picks active cue', () {
      final cues = parseWebVtt('''WEBVTT

1
00:00:01.000 --> 00:00:02.000
A

2
00:00:03.000 --> 00:00:04.000
B
''');
      expect(cuesAt(cues, const Duration(milliseconds: 500)), isEmpty);
      expect(cuesAt(cues, const Duration(milliseconds: 1500)).single.text, 'A');
      expect(cuesAt(cues, const Duration(milliseconds: 3500)).single.text, 'B');
      expect(cuesAt(cues, const Duration(milliseconds: 2000)), isEmpty);
    });

    test('empty / invalid yields empty list', () {
      expect(parseWebVtt(''), isEmpty);
      expect(parseWebVtt('WEBVTT\n\n'), isEmpty);
    });
  });
}
