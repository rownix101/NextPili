import 'dart:async';
import 'dart:io' show File, Platform, Process;

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

/// Linux desktop wallpaper path for simulated Mica plate.
///
/// macOS uses native VisualEffect; Windows uses DWM. Linux has no material API,
/// so we sample wallpaper once (Mica-like), not live compositor blur.
/// docs/ux/design-system.md §2.2.1
abstract final class DesktopWallpaper {
  static final ValueNotifier<String?> path = ValueNotifier<String?>(null);

  static Timer? _poll;
  static bool _loading = false;

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }

  /// Resolve wallpaper; start light polling for path changes.
  static Future<void> ensureLoaded() async {
    if (!isSupported) return;
    await refresh();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) {
      // ignore: discarded_futures
      refresh();
    });
  }

  static Future<void> refresh() async {
    if (!isSupported || _loading) return;
    _loading = true;
    try {
      final next = await _resolveLinux();
      if (next != path.value) {
        path.value = next;
        debugPrint(
          next == null
              ? 'DesktopWallpaper: no sample'
              : 'DesktopWallpaper: $next',
        );
      }
    } catch (e, st) {
      debugPrint('DesktopWallpaper refresh failed: $e\n$st');
    } finally {
      _loading = false;
    }
  }

  static Future<String?> _resolveLinux() async {
    for (final candidate in await _linuxCandidates()) {
      final file = File(candidate);
      if (await file.exists()) return candidate;
    }
    return null;
  }

  static Future<List<String>> _linuxCandidates() async {
    final out = <String>[];

    final gnome = await _gnomePictureUri();
    if (gnome != null) out.add(gnome);

    final kde = await _kdeImagePath();
    if (kde != null) out.add(kde);

    final xfce = await _xfceLastImage();
    if (xfce != null) out.add(xfce);

    final mate = await _gsettingsString(
      'org.mate.background',
      'picture-filename',
    );
    if (mate != null) out.add(mate);

    final cinnamon = await _gsettingsString(
      'org.cinnamon.desktop.background',
      'picture-uri',
    );
    final cinnamonPath = parseFileUri(cinnamon);
    if (cinnamonPath != null) out.add(cinnamonPath);

    return out;
  }

  static Future<String?> _gnomePictureUri() async {
    final scheme = await _gsettingsString(
      'org.gnome.desktop.interface',
      'color-scheme',
    );
    final preferDark = (scheme ?? '').contains('prefer-dark');
    if (preferDark) {
      final dark = await _gsettingsString(
        'org.gnome.desktop.background',
        'picture-uri-dark',
      );
      final darkPath = parseFileUri(dark);
      if (darkPath != null) return darkPath;
    }
    final light = await _gsettingsString(
      'org.gnome.desktop.background',
      'picture-uri',
    );
    return parseFileUri(light);
  }

  static Future<String?> _kdeImagePath() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    final cfg = File(
      p.join(home, '.config', 'plasma-org.kde.plasma.desktop-appletsrc'),
    );
    if (!await cfg.exists()) return null;
    try {
      final lines = await cfg.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('Image=')) continue;
        final raw = trimmed.substring('Image='.length).trim();
        final path = parseFileUri(raw) ??
            (raw.startsWith('/') ? raw : null);
        if (path != null) return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _xfceLastImage() async {
    // Common XFCE backdrop keys; first hit wins.
    const keys = [
      '/backdrop/screen0/monitor0/workspace0/last-image',
      '/backdrop/screen0/monitorscreen/workspace0/last-image',
      '/backdrop/screen0/monitorLVDS-1/workspace0/last-image',
      '/backdrop/screen0/monitorHDMI-1/workspace0/last-image',
      '/backdrop/screen0/monitoreDP-1/workspace0/last-image',
    ];
    for (final key in keys) {
      final r = await _run('xfconf-query', ['-c', 'xfce4-desktop', '-p', key]);
      if (r == null) continue;
      final path = r.trim();
      if (path.isNotEmpty && !path.startsWith('Failed')) return path;
    }
    return null;
  }

  static Future<String?> _gsettingsString(String schema, String key) async {
    final r = await _run('gsettings', ['get', schema, key]);
    if (r == null) return null;
    return stripGsettingsQuotes(r.trim());
  }

  /// `file:///path` / `'file:///path'` / plain path → filesystem path.
  static String? parseFileUri(String? raw) {
    if (raw == null) return null;
    var s = stripGsettingsQuotes(raw.trim());
    if (s.isEmpty || s == "''" || s == '""') return null;
    if (s.startsWith('file://')) {
      try {
        return Uri.parse(s).toFilePath();
      } catch (_) {
        s = Uri.decodeFull(s.substring('file://'.length));
      }
    }
    if (s.startsWith('/')) return s;
    return null;
  }

  static String stripGsettingsQuotes(String s) {
    if (s.length >= 2) {
      final a = s.codeUnitAt(0);
      final b = s.codeUnitAt(s.length - 1);
      if ((a == 0x27 && b == 0x27) || (a == 0x22 && b == 0x22)) {
        return s.substring(1, s.length - 1);
      }
    }
    return s;
  }

  static Future<String?> _run(String exe, List<String> args) async {
    try {
      final result = await Process.run(exe, args, runInShell: false);
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String?)?.trim();
      if (out == null || out.isEmpty) return null;
      return out;
    } catch (_) {
      return null;
    }
  }
}
