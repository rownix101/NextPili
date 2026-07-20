import 'package:flutter/animation.dart';

/// Easing tokens — docs/ux/motion.md §3.
abstract final class AppEasing {
  static const linear = Curves.linear;
  static const standard = Curves.easeInOutCubic;
  static const standardDecelerate = Curves.easeOutCubic;
  static const standardAccelerate = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Large panel enter (fast out, soft settle).
  static const emphasizedDecelerate = Curves.easeOutCubic;

  /// Large panel leave (slow start, quick exit).
  static const emphasizedAccelerate = Curves.easeInCubic;
}
