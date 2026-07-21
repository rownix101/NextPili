import 'package:flutter/foundation.dart' show debugPrint;
import 'package:window_manager/window_manager.dart';

import 'desktop_window.dart';

/// OS-level window fullscreen (`window_manager`), separate from player surface host.
///
/// docs/ux/interaction.md §4.4 · multi-platform.md §8
abstract final class DesktopOsFullscreen {
  /// Enter or leave exclusive/borderless OS fullscreen on desktop.
  ///
  /// No-op on non-desktop. Idempotent when already in the requested state.
  static Future<void> setEnabled(bool enabled) async {
    if (!DesktopWindow.isDesktop) return;
    try {
      final current = await windowManager.isFullScreen();
      if (current == enabled) return;
      await windowManager.setFullScreen(enabled);
    } catch (e, st) {
      debugPrint('DesktopOsFullscreen.setEnabled($enabled) failed: $e\n$st');
    }
  }
}
