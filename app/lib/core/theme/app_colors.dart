import 'package:flutter/material.dart';

import 'palette.dart';

/// Semantic app colors — docs/ux/design-system.md §3.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.secondary,
    required this.tertiary,
    required this.canvas,
    required this.elevated,
    required this.sunken,
    required this.fgPrimary,
    required this.fgSecondary,
    required this.fgMuted,
    required this.borderSubtle,
    required this.borderStrong,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.live,
    required this.vip,
    required this.glassTintNeutral,
    required this.glassTintChrome,
    required this.glassTintAccent,
  });

  final Color accent;
  final Color onAccent;
  final Color secondary;
  final Color tertiary;
  final Color canvas;
  final Color elevated;
  final Color sunken;
  final Color fgPrimary;
  final Color fgSecondary;
  final Color fgMuted;
  final Color borderSubtle;
  final Color borderStrong;
  final Color error;
  final Color success;
  final Color warning;
  final Color info;
  final Color live;
  final Color vip;
  final Color glassTintNeutral;
  final Color glassTintChrome;
  final Color glassTintAccent;

  static const light = AppColors(
    accent: Palette.accentLight,
    onAccent: Palette.onAccentLight,
    secondary: Palette.secondaryLight,
    tertiary: Palette.tertiaryLight,
    canvas: Palette.canvasLight,
    elevated: Palette.elevatedLight,
    sunken: Palette.sunkenLight,
    fgPrimary: Palette.fgPrimaryLight,
    fgSecondary: Palette.fgSecondaryLight,
    fgMuted: Palette.fgMuted,
    borderSubtle: Palette.borderSubtleLight,
    borderStrong: Palette.borderStrongLight,
    error: Palette.errorLight,
    success: Palette.successLight,
    warning: Palette.warningLight,
    info: Palette.infoLight,
    live: Palette.liveLight,
    vip: Palette.vipLight,
    glassTintNeutral: Palette.glassTintNeutralLight,
    glassTintChrome: Palette.glassTintChromeLight,
    glassTintAccent: Palette.glassTintAccentLight,
  );

  static const dark = AppColors(
    accent: Palette.accentDark,
    onAccent: Palette.onAccentDark,
    secondary: Palette.secondaryDark,
    tertiary: Palette.tertiaryDark,
    canvas: Palette.canvasDark,
    elevated: Palette.elevatedDark,
    sunken: Palette.sunkenDark,
    fgPrimary: Palette.fgPrimaryDark,
    fgSecondary: Palette.fgSecondaryDark,
    fgMuted: Palette.fgMuted,
    borderSubtle: Palette.borderSubtleDark,
    borderStrong: Palette.borderStrongDark,
    error: Palette.errorDark,
    success: Palette.successDark,
    warning: Palette.warningDark,
    info: Palette.infoDark,
    live: Palette.liveDark,
    vip: Palette.vipDark,
    glassTintNeutral: Palette.glassTintNeutralDark,
    glassTintChrome: Palette.glassTintChromeDark,
    glassTintAccent: Palette.glassTintAccentDark,
  );

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    assert(ext != null, 'AppColors ThemeExtension missing — use buildAppTheme()');
    return ext ?? (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? secondary,
    Color? tertiary,
    Color? canvas,
    Color? elevated,
    Color? sunken,
    Color? fgPrimary,
    Color? fgSecondary,
    Color? fgMuted,
    Color? borderSubtle,
    Color? borderStrong,
    Color? error,
    Color? success,
    Color? warning,
    Color? info,
    Color? live,
    Color? vip,
    Color? glassTintNeutral,
    Color? glassTintChrome,
    Color? glassTintAccent,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      canvas: canvas ?? this.canvas,
      elevated: elevated ?? this.elevated,
      sunken: sunken ?? this.sunken,
      fgPrimary: fgPrimary ?? this.fgPrimary,
      fgSecondary: fgSecondary ?? this.fgSecondary,
      fgMuted: fgMuted ?? this.fgMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      live: live ?? this.live,
      vip: vip ?? this.vip,
      glassTintNeutral: glassTintNeutral ?? this.glassTintNeutral,
      glassTintChrome: glassTintChrome ?? this.glassTintChrome,
      glassTintAccent: glassTintAccent ?? this.glassTintAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      fgPrimary: Color.lerp(fgPrimary, other.fgPrimary, t)!,
      fgSecondary: Color.lerp(fgSecondary, other.fgSecondary, t)!,
      fgMuted: Color.lerp(fgMuted, other.fgMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      live: Color.lerp(live, other.live, t)!,
      vip: Color.lerp(vip, other.vip, t)!,
      glassTintNeutral: Color.lerp(glassTintNeutral, other.glassTintNeutral, t)!,
      glassTintChrome: Color.lerp(glassTintChrome, other.glassTintChrome, t)!,
      glassTintAccent: Color.lerp(glassTintAccent, other.glassTintAccent, t)!,
    );
  }
}
