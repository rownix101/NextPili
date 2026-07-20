import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic haptics — docs/ux/interaction.md §6.4.
///
/// Feature code only calls these APIs. No-ops when disabled or unsupported.
abstract final class Haptics {
  /// `null` = auto (touch platforms on, pure-pointer desktop off).
  static bool? userEnabled;

  static bool get _enabled {
    if (userEnabled != null) return userEnabled!;
    // Auto: mobile / touch-first on; desktop pointer default off.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  static Future<void> selection() => _run(HapticFeedback.selectionClick);

  static Future<void> impactLight() => _run(HapticFeedback.lightImpact);

  static Future<void> impactMedium() => _run(HapticFeedback.mediumImpact);

  static Future<void> impactHeavy() => _run(HapticFeedback.heavyImpact);

  /// Positive completion (login, major confirm). Prefer [impactLight] for light
  /// actions like favorite / copy.
  static Future<void> success() => _run(HapticFeedback.mediumImpact);

  static Future<void> warning() => _run(HapticFeedback.mediumImpact);

  static Future<void> error() => _run(HapticFeedback.vibrate);

  static Future<void> boundary() => _run(HapticFeedback.lightImpact);

  static Future<void> snap() => _run(HapticFeedback.selectionClick);

  static Future<void> _run(Future<void> Function() fn) async {
    if (!_enabled) return;
    try {
      await fn();
    } catch (_) {
      // Capability missing — silent no-op.
    }
  }
}
