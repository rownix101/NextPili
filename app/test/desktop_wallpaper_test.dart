import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/core/adaptive/desktop_wallpaper.dart';

void main() {
  group('DesktopWallpaper.parseFileUri', () {
    test('file URI with quotes', () {
      expect(
        DesktopWallpaper.parseFileUri("'file:///home/u/Pictures/a.jpg'"),
        '/home/u/Pictures/a.jpg',
      );
    });

    test('file URI with spaces', () {
      expect(
        DesktopWallpaper.parseFileUri('file:///home/u/My%20Wall.jpg'),
        '/home/u/My Wall.jpg',
      );
    });

    test('plain absolute path', () {
      expect(
        DesktopWallpaper.parseFileUri('/usr/share/backgrounds/x.png'),
        '/usr/share/backgrounds/x.png',
      );
    });

    test('empty and junk', () {
      expect(DesktopWallpaper.parseFileUri(null), isNull);
      expect(DesktopWallpaper.parseFileUri("''"), isNull);
      expect(DesktopWallpaper.parseFileUri(''), isNull);
      expect(DesktopWallpaper.parseFileUri('not-a-path'), isNull);
    });
  });

  group('DesktopWallpaper.stripGsettingsQuotes', () {
    test('single and double quotes', () {
      expect(DesktopWallpaper.stripGsettingsQuotes("'abc'"), 'abc');
      expect(DesktopWallpaper.stripGsettingsQuotes('"abc"'), 'abc');
      expect(DesktopWallpaper.stripGsettingsQuotes('abc'), 'abc');
    });
  });
}
