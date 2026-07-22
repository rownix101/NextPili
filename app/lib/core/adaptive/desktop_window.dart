import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_wallpaper.dart';

/// How the desktop shell reveals OS wallpaper / system backdrop.
///
/// docs/ux/design-system.md §2.2.1
enum DesktopBackdrop {
  /// Opaque canvas; init failed or non-desktop.
  none,

  /// Transparent window + Flutter sample/tint (Linux; Win fallback).
  simulatedPierce,

  /// Windows 11 DWM Mica (`flutter_acrylic` / [WindowEffect.mica]).
  windowsMica,

  /// Windows 10+ Acrylic when Mica is unavailable.
  windowsAcrylic,

  /// macOS [NSVisualEffectView] material (`sidebar` / related).
  macOsVisualEffect,
}

/// Desktop window chrome — native materials or transparent pierce.
///
/// docs/ux/design-system.md §2 · docs/ux/multi-platform.md §6
abstract final class DesktopWindow {
  static DesktopBackdrop _backdrop = DesktopBackdrop.none;
  static bool? _lastDark;
  static bool _acrylicReady = false;

  /// True when the OS window is transparent or uses a system backdrop so
  /// chrome gaps can reveal wallpaper / Mica.
  static bool get desktopPierceEnabled =>
      _backdrop != DesktopBackdrop.none;

  /// System material already paints under the window (skip heavy Flutter plate).
  static bool get nativeSystemBackdrop =>
      _backdrop == DesktopBackdrop.windowsMica ||
      _backdrop == DesktopBackdrop.windowsAcrylic ||
      _backdrop == DesktopBackdrop.macOsVisualEffect;

  /// Windows DWM Mica or Acrylic is active.
  static bool get nativeWindowsBackdrop =>
      _backdrop == DesktopBackdrop.windowsMica ||
      _backdrop == DesktopBackdrop.windowsAcrylic;

  static DesktopBackdrop get backdrop => _backdrop;

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  static bool _envFlag(String name) {
    final v = Platform.environment[name]?.trim().toLowerCase();
    if (v == null || v.isEmpty) return false;
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }

  /// `NEXTPILI_NO_PIERCE=1` → opaque shell (no transparent backdrop / blur).
  /// Pair with Linux runner (`my_application.cc`).
  static bool get pierceDisabledByEnv => _envFlag('NEXTPILI_NO_PIERCE');

  /// `NEXTPILI_NO_BLUR=1` → keep transparent pierce; skip compositor blur only.
  /// Linux runner honors this; Dart skips wallpaper sample plate for cleaner A/B.
  static bool get blurDisabledByEnv => _envFlag('NEXTPILI_NO_BLUR');

  /// Call after [WidgetsFlutterBinding.ensureInitialized], before [runApp].
  ///
  /// Does not block on first frame: [waitUntilReadyToShow] shows the window
  /// after Flutter paints (must not `await` past [runApp]).
  static Future<void> ensureInitialized() async {
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();

      if (pierceDisabledByEnv) {
        _backdrop = DesktopBackdrop.none;
        const opaqueOptions = WindowOptions(
          minimumSize: Size(800, 500),
          backgroundColor: Color(0xFF0B0F1A),
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );
        // ignore: unawaited_futures
        windowManager.waitUntilReadyToShow(opaqueOptions, () async {
          await windowManager.setBackgroundColor(const Color(0xFF0B0F1A));
          await windowManager.show();
          await windowManager.focus();
        });
        await windowManager.setBackgroundColor(const Color(0xFF0B0F1A));
        debugPrint(
          'DesktopWindow: pierce disabled (NEXTPILI_NO_PIERCE) — opaque shell',
        );
        return;
      }

      await _initAcrylic();

      const options = WindowOptions(
        minimumSize: Size(800, 500),
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      final dark = _platformPrefersDark();

      // Fire-and-forget: show after first frame; do not block runApp.
      // ignore: unawaited_futures
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setBackgroundColor(Colors.transparent);
        await _applyBackdrop(dark: dark);
        await windowManager.show();
        await windowManager.focus();
      });

      await windowManager.setBackgroundColor(Colors.transparent);
      await _applyBackdrop(dark: dark);

      // Linux only: wallpaper sample plate (not compositor live blur).
      // Skip under NEXTPILI_NO_BLUR so A/B isolates transparent pierce alone.
      if (Platform.isLinux &&
          _backdrop == DesktopBackdrop.simulatedPierce &&
          !blurDisabledByEnv) {
        // ignore: unawaited_futures
        DesktopWallpaper.ensureLoaded();
      } else if (blurDisabledByEnv) {
        debugPrint(
          'DesktopWindow: blur disabled (NEXTPILI_NO_BLUR) — pierce without blur plate',
        );
      }
    } catch (e, st) {
      debugPrint('DesktopWindow init failed: $e\n$st');
      _backdrop = DesktopBackdrop.none;
    }
  }

  /// Keep system material in sync with app light/dark (theme changes).
  static Future<void> syncBrightness(Brightness brightness) async {
    if (!isDesktop) return;
    if (_backdrop == DesktopBackdrop.none) return;
    // Linux transparent has no dark flag; skip re-apply (avoids hide/show).
    if (Platform.isLinux) return;

    final dark = brightness == Brightness.dark;
    if (_lastDark == dark) return;
    await _applyBackdrop(dark: dark);
  }

  static Future<void> _initAcrylic() async {
    try {
      await Window.initialize();
      _acrylicReady = true;
    } catch (e, st) {
      debugPrint('DesktopWindow: flutter_acrylic init failed: $e\n$st');
      _acrylicReady = false;
    }
  }

  static bool _platformPrefersDark() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  static Future<void> _applyBackdrop({required bool dark}) async {
    _lastDark = dark;

    if (Platform.isWindows) {
      final ok = await _tryWindowsNative(dark: dark);
      if (ok) return;
    }

    if (Platform.isMacOS) {
      final ok = await _tryMacOsVisualEffect(dark: dark);
      if (ok) return;
    }

    if (Platform.isLinux) {
      final ok = await _tryLinuxTransparent();
      if (ok) return;
    }

    // Ultimate fallback: window_manager transparent only.
    try {
      await windowManager.setBackgroundColor(Colors.transparent);
      if (_acrylicReady && Platform.isWindows) {
        try {
          await Window.setEffect(
            effect: WindowEffect.transparent,
            color: const Color(0x00000000),
            dark: dark,
          );
        } catch (_) {}
      }
      _backdrop = DesktopBackdrop.simulatedPierce;
    } catch (e, st) {
      debugPrint('DesktopWindow simulated pierce failed: $e\n$st');
      _backdrop = DesktopBackdrop.none;
    }
  }

  /// Win11 build ≥ 22000 → Mica; older → Acrylic.
  static Future<bool> _tryWindowsNative({required bool dark}) async {
    if (!_acrylicReady) return false;
    final build = _windowsBuildNumber();
    try {
      if (build >= 22000) {
        await Window.setEffect(
          effect: WindowEffect.mica,
          color: const Color(0x00000000),
          dark: dark,
        );
        _backdrop = DesktopBackdrop.windowsMica;
        debugPrint(
          'DesktopWindow: native Mica (build=$build, dark=$dark)',
        );
        return true;
      }

      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: dark
            ? const Color(0xCC0B0F1A)
            : const Color(0xCCF4F6FA),
        dark: dark,
      );
      _backdrop = DesktopBackdrop.windowsAcrylic;
      debugPrint(
        'DesktopWindow: Acrylic (build=$build, dark=$dark)',
      );
      return true;
    } catch (e, st) {
      debugPrint('DesktopWindow: Windows native failed: $e\n$st');
      return false;
    }
  }

  /// macOS [NSVisualEffectView] — sidebar material (rail chrome).
  static Future<bool> _tryMacOsVisualEffect({required bool dark}) async {
    if (!_acrylicReady) return false;
    try {
      await Window.setEffect(
        effect: WindowEffect.sidebar,
        dark: dark,
      );
      try {
        await Window.overrideMacOSBrightness(dark: dark);
      } catch (_) {}
      _backdrop = DesktopBackdrop.macOsVisualEffect;
      debugPrint('DesktopWindow: macOS VisualEffect sidebar (dark=$dark)');
      return true;
    } catch (e, st) {
      debugPrint('DesktopWindow: macOS VisualEffect failed: $e\n$st');
      return false;
    }
  }

  /// Linux: transparent window. Real-time blur is **compositor-side**
  /// (`linux/runner/desktop_compositor_blur.cc`:
  /// Wayland `ext-background-effect-v1`, X11 KWin blur atom).
  /// Flutter [BackdropFilter] cannot blur the desktop.
  /// Wallpaper sample in [DesktopWallpaper] is only a static fallback plate.
  static Future<bool> _tryLinuxTransparent() async {
    try {
      await windowManager.setBackgroundColor(Colors.transparent);
      if (_acrylicReady) {
        await Window.setEffect(
          effect: WindowEffect.transparent,
          color: const Color(0x00000000),
        );
      }
      _backdrop = DesktopBackdrop.simulatedPierce;
      debugPrint(
        'DesktopWindow: Linux transparent (compositor blur via runner)',
      );
      return true;
    } catch (e, st) {
      debugPrint('DesktopWindow: Linux transparent failed: $e\n$st');
      return false;
    }
  }

  /// Parses `Platform.operatingSystemVersion` (e.g. `... Build 22631`).
  static int _windowsBuildNumber() {
    final match = RegExp(
      r'Build[^\d]*(\d+)',
      caseSensitive: false,
    ).firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
