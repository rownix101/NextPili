import 'package:flutter/animation.dart';

/// Easing tokens — docs/ux/motion.md §3.
///
/// Material semantic names stay fixed; control points use stronger custom
/// cubics so UI feels responsive (enter fast / leave decisive) rather than the
/// soft stock [Curves.easeOutCubic] / [Curves.easeInOutCubic].
abstract final class AppEasing {
  /// Constant speed — progress bars, marquee, premium shimmer.
  static const linear = Curves.linear;

  /// On-screen morph / property change (strong ease-in-out).
  /// cubic-bezier(0.77, 0, 0.175, 1)
  static const standard = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Element **enter** — fast out, soft settle (strong ease-out).
  /// cubic-bezier(0.23, 1, 0.32, 1)
  static const standardDecelerate = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Element **leave** — slow start, quick exit (Material accelerate).
  /// cubic-bezier(0.55, 0.055, 0.675, 1) — punchier ease-in than stock.
  static const standardAccelerate = Cubic(0.55, 0.055, 0.675, 1.0);

  /// Emphasized container morph (keeps Flutter’s emphasized curve).
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Large panel enter (fast out, soft settle).
  static const emphasizedDecelerate = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Large panel leave (slow start, quick exit).
  static const emphasizedAccelerate = Cubic(0.55, 0.055, 0.675, 1.0);
}
