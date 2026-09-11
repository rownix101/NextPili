import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart' show Color, Size;
import 'package:window_manager/window_manager.dart';

/// Desktop window setup — opaque native window with platform decorations.
///
/// The Flutter shell paints its own canvas and chrome surfaces; the native
/// window stays opaque and does not request system materials.
abstract final class DesktopWindow {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  /// Call after [WidgetsFlutterBinding.ensureInitialized], before [runApp].
  ///
  /// Does not block on first frame: [waitUntilReadyToShow] shows the window
  /// after Flutter paints.
  static Future<void> ensureInitialized() async {
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();

      const options = WindowOptions(
        minimumSize: Size(800, 500),
        backgroundColor: Color(0xFF0B0F1A),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      // Fire-and-forget: show after first frame; do not block runApp.
      // ignore: unawaited_futures
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      await windowManager.setBackgroundColor(const Color(0xFF0B0F1A));
    } catch (e, st) {
      debugPrint('DesktopWindow init failed: $e\n$st');
    }
  }
}
