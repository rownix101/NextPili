import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Inter + system CJK fallback — design-system §5.
abstract final class AppTextThemes {
  static List<String> get cjkFallback {
    if (kIsWeb) return const ['sans-serif'];
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const ['PingFang SC', 'Hiragino Sans GB', 'sans-serif'];
      case TargetPlatform.windows:
        return const ['Microsoft YaHei UI', 'Microsoft YaHei', 'sans-serif'];
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return const [
          'Noto Sans CJK SC',
          'Source Han Sans SC',
          'WenQuanYi Micro Hei',
          'sans-serif',
        ];
    }
  }

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required double height,
    Color? color,
    bool tabular = false,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    ).copyWith(fontFamilyFallback: cjkFallback);
  }

  static TextTheme build(AppColors colors) {
    return TextTheme(
      displayLarge: _inter(
        size: 28,
        weight: FontWeight.w600,
        height: 1.2,
        color: colors.fgPrimary,
      ),
      headlineMedium: _inter(
        size: 22,
        weight: FontWeight.w600,
        height: 1.25,
        color: colors.fgPrimary,
      ),
      titleLarge: _inter(
        size: 18,
        weight: FontWeight.w600,
        height: 1.3,
        color: colors.fgPrimary,
      ),
      titleMedium: _inter(
        size: 16,
        weight: FontWeight.w600,
        height: 1.3,
        color: colors.fgPrimary,
      ),
      titleSmall: _inter(
        size: 14,
        weight: FontWeight.w500,
        height: 1.35,
        color: colors.fgPrimary,
      ),
      bodyLarge: _inter(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
        color: colors.fgPrimary,
      ),
      bodyMedium: _inter(
        size: 14,
        weight: FontWeight.w400,
        height: 1.5,
        color: colors.fgPrimary,
      ),
      bodySmall: _inter(
        size: 12,
        weight: FontWeight.w400,
        height: 1.4,
        color: colors.fgSecondary,
      ),
      labelLarge: _inter(
        size: 14,
        weight: FontWeight.w600,
        height: 1.2,
        color: colors.fgPrimary,
      ),
      labelMedium: _inter(
        size: 13,
        weight: FontWeight.w500,
        height: 1.2,
        color: colors.fgPrimary,
      ),
      labelSmall: _inter(
        size: 11,
        weight: FontWeight.w500,
        height: 1.3,
        color: colors.fgMuted,
        tabular: true,
      ),
    );
  }

  /// Meta / duration numbers with tabular figures.
  static TextStyle meta(BuildContext context, {Color? color}) {
    final colors = AppColors.of(context);
    return _inter(
      size: 12,
      weight: FontWeight.w400,
      height: 1.4,
      color: color ?? colors.fgSecondary,
      tabular: true,
    );
  }
}
