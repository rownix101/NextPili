/// Duration tokens — docs/ux/motion.md §2.
abstract final class AppDuration {
  /// True zero — reduce-motion collapse, skip enter/exit.
  static const none = Duration.zero;

  /// Near-instant micro feedback when a zero-length frame is undesirable.
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
