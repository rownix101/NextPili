import 'dart:io' show File;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../adaptive/desktop_wallpaper.dart';
import '../adaptive/desktop_window.dart';
import '../theme/app_colors.dart';
import '../theme/mica_tokens.dart';
import '../theme/shapes.dart';

/// Rail chrome surface: native system material, Linux wallpaper sample, or tint.
///
/// When [DesktopWindow.nativeSystemBackdrop] is true (Windows DWM or macOS
/// VisualEffect), the OS already paints material — this widget stays nearly clear.
///
/// On Linux transparent pierce, prefers a **sampled wallpaper** (blur + tint).
/// [BackdropFilter] cannot blur the desktop, so it is not used for pierce chrome.
///
/// Prefer for static desktop chrome (Rail). Do not use on scrolling lists.
///
/// docs/ux/design-system.md §2.2.1 / §2.5
class MicaSurface extends StatelessWidget {
  const MicaSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.blurSigma = MicaTokens.blurSigma,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurSigma;

  /// High contrast / invert → solid surface (no pierce tint).
  static bool get _preferOpaque {
    final features =
        SchedulerBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.highContrast || features.invertColors;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: DesktopWallpaper.path,
      builder: (context, wallpaperPath, _) {
        return _buildSurface(context, wallpaperPath);
      },
    );
  }

  Widget _buildSurface(BuildContext context, String? wallpaperPath) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppShapes.borderLg;
    final native = DesktopWindow.nativeSystemBackdrop && !_preferOpaque;
    final pierce =
        DesktopWindow.desktopPierceEnabled && !_preferOpaque && !native;
    final wallpaper = (wallpaperPath != null && wallpaperPath.isNotEmpty)
        ? wallpaperPath
        : null;
    final sample = pierce && wallpaper != null && blurSigma > 0;

    final Color tint;
    final Color luminosity;
    final List<BoxShadow>? shadows;

    if (_preferOpaque || !DesktopWindow.desktopPierceEnabled) {
      final alpha = isDark
          ? MicaTokens.tintAlphaDarkSolid
          : MicaTokens.tintAlphaLightSolid;
      tint = colors.canvas.withValues(alpha: alpha);
      luminosity = Colors.white.withValues(
        alpha: isDark
            ? MicaTokens.luminosityAlphaDark
            : MicaTokens.luminosityAlphaLight,
      );
      shadows = null;
    } else if (native) {
      tint = colors.canvas.withValues(
        alpha: isDark
            ? MicaTokens.tintAlphaDarkNative
            : MicaTokens.tintAlphaLightNative,
      );
      luminosity = Colors.white.withValues(
        alpha: isDark ? 0.02 : 0.04,
      );
      shadows = null;
    } else if (sample) {
      tint = colors.canvas.withValues(
        alpha: isDark
            ? MicaTokens.tintAlphaDarkSample
            : MicaTokens.tintAlphaLightSample,
      );
      luminosity = Colors.white.withValues(
        alpha: isDark
            ? MicaTokens.luminosityAlphaDark
            : MicaTokens.luminosityAlphaLight,
      );
      // Edge-flush chrome (zero radius) — no floating shadow.
      shadows = radius == BorderRadius.zero
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: MicaTokens.shadowAlpha),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ];
    } else {
      tint = colors.canvas.withValues(
        alpha: isDark
            ? MicaTokens.tintAlphaDarkPierce
            : MicaTokens.tintAlphaLightPierce,
      );
      luminosity = Colors.white.withValues(
        alpha: isDark
            ? MicaTokens.luminosityAlphaDark
            : MicaTokens.luminosityAlphaLight,
      );
      shadows = radius == BorderRadius.zero
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: MicaTokens.shadowAlpha),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ];
    }

    final borderColor =
        colors.borderSubtle.withValues(alpha: MicaTokens.borderAlpha);

    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    final overlay = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(luminosity, tint),
            tint,
          ],
        ),
      ),
      child: content,
    );

    final Widget fill;
    if (sample) {
      fill = Stack(
        fit: StackFit.expand,
        children: [
          _SampledWallpaper(path: wallpaper, blurSigma: blurSigma),
          overlay,
        ],
      );
    } else {
      fill = overlay;
    }

    Widget surface = ClipRRect(borderRadius: radius, child: fill);
    if (shadows != null) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows,
        ),
        child: surface,
      );
    }

    return SizedBox(width: width, height: height, child: surface);
  }
}

/// Low-res wallpaper plate + Gaussian blur (Mica sample path).
class _SampledWallpaper extends StatelessWidget {
  const _SampledWallpaper({
    required this.path,
    required this.blurSigma,
  });

  final String path;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final provider = ResizeImage(
      FileImage(File(path)),
      width: MicaTokens.sampleDecodeWidth,
      policy: ResizeImagePolicy.fit,
    );

    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.clamp,
      ),
      child: Image(
        image: provider,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const SizedBox.expand();
        },
      ),
    );
  }
}
