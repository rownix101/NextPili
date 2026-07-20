import 'package:flutter/animation.dart';

/// Motion tokens — docs/ux/motion.md.
abstract final class AppDuration {
  static const instant = Duration(milliseconds: 50);
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const medium1 = Duration(milliseconds: 200);
  static const medium2 = Duration(milliseconds: 250);
  static const medium3 = Duration(milliseconds: 300);
  static const long1 = Duration(milliseconds: 400);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 600);
  static const playerChrome = Duration(milliseconds: 200);
  static const playerChromeDelay = Duration(milliseconds: 2800);
}

abstract final class AppEasing {
  static const linear = Curves.linear;
  static const standard = Curves.easeInOutCubic;
  static const standardDecelerate = Curves.easeOutCubic;
  static const standardAccelerate = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;
}
