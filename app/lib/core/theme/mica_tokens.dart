/// Mica chrome tokens — native Windows + wallpaper-sample / pierce fallback.
///
/// docs/ux/design-system.md §2.2.1 / §2.5 (desktop rail)
abstract final class MicaTokens {
  /// Soft diffuse blur on **sampled** wallpaper (not BackdropFilter).
  static const double blurSigma = 36;

  /// Max decode width for wallpaper sample (Mica-like low-res plate).
  static const int sampleDecodeWidth = 480;

  /// Wallpaper sample path — light wash over blurred plate.
  static const double tintAlphaLightSample = 0.42;
  static const double tintAlphaDarkSample = 0.48;

  /// Pierce without sample (live transparent only) — heavier tint.
  static const double tintAlphaLightPierce = 0.58;
  static const double tintAlphaDarkPierce = 0.50;

  /// Native Windows Mica/Acrylic — keep low so DWM material stays visible.
  static const double tintAlphaLightNative = 0.10;
  static const double tintAlphaDarkNative = 0.08;

  /// Near-opaque fallback when pierce/backdrop is off or a11y prefers opaque.
  static const double tintAlphaLightSolid = 0.94;
  static const double tintAlphaDarkSolid = 0.92;

  /// Extra luminosity wash (sample / pierce paths).
  static const double luminosityAlphaLight = 0.08;
  static const double luminosityAlphaDark = 0.05;

  static const double borderAlpha = 0.42;
  static const double shadowAlpha = 0.12;
}
