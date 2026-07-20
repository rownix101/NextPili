/// 4dp grid spacing tokens — design-system §6.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Page horizontal inset by width.
  static double pagePaddingH(double width) {
    if (width < 600) return md;
    if (width < 840) return lg;
    if (width < 1200) return lg;
    return xl;
  }

  static const double contentMaxWidth = 1600;
}
