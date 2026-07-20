import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'palette.dart';

/// GlassThemeData assembly — design-system §4.4 / §10.1.
abstract final class NextPiliGlassTheme {
  static final data = GlassThemeData(
    light: GlassThemeVariant(
      settings: GlassThemeSettings(
        blur: 6,
        thickness: 26,
        glassColor: Palette.glassTintNeutralLight,
        lightIntensity: 0.5,
        refractiveIndex: 1.18,
        saturation: 1.35,
        chromaticAberration: 0.02,
        ambientStrength: 0.08,
        specularSharpness: GlassSpecularSharpness.medium,
      ),
      quality: GlassQuality.standard,
      glowColors: const GlassGlowColors(primary: Palette.accentLight),
    ),
    dark: GlassThemeVariant(
      settings: GlassThemeSettings(
        blur: 8,
        thickness: 32,
        glassColor: Palette.glassTintNeutralDark,
        lightIntensity: 0.6,
        refractiveIndex: 1.18,
        saturation: 1.35,
        chromaticAberration: 0.02,
        ambientStrength: 0.08,
        specularSharpness: GlassSpecularSharpness.medium,
      ),
      quality: GlassQuality.standard,
      glowColors: const GlassGlowColors(primary: Palette.accentDark),
    ),
  );
}
