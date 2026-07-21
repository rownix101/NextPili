import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/shapes.dart';

/// Liquid Glass tray for **chrome / floating controls only**.
///
/// Use for: floating pills, settings grouped chrome, modal trays over content.
/// Do **not** wrap watch-page content rails (UP / parts / related), feed cards,
/// or list bodies — those stay [ContentSurface] (design-system §2 Glass vs
/// Content). Never nest another glass control inside (design-system §2.3).
///
/// Recipe: own layer + standard quality + chrome tint
/// (`liquid_glass_widgets` Surfaces / GlassContainer).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppShapes.md,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  /// Shared chrome settings (settings groups, floating trays).
  static LiquidGlassSettings settings(AppColors colors) {
    return LiquidGlassSettings(
      glassColor: colors.glassTintChrome,
      thickness: 28,
      blur: 4,
      chromaticAberration: 0.02,
      lightIntensity: 0.5,
      ambientStrength: 0.08,
      refractiveIndex: 1.2,
      saturation: 1.2,
      specularSharpness: GlassSpecularSharpness.medium,
    );
  }

  /// Always-dark player chrome (icon pills / settings tray over video).
  ///
  /// Prefer **pill-scoped** glass around icon clusters — not a full-width
  /// bar covering the seek track (design-system §2.5 player chrome).
  static LiquidGlassSettings playerChromeSettings(Color chromeTint) {
    return LiquidGlassSettings(
      glassColor: chromeTint,
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.01,
      lightIntensity: 0.45,
      ambientStrength: 0.06,
      refractiveIndex: 1.2,
      saturation: 1.15,
      specularSharpness: GlassSpecularSharpness.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: settings(colors),
      padding: padding,
      child: child,
    );
  }
}
