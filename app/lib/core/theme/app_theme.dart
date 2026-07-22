import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'player_colors.dart';
import 'shapes.dart';
import 'text_themes.dart';

/// ThemeData carrier for NextPili tokens (not M3 visual language).
/// ColorScheme is filled only for third-party / base control compatibility.
ThemeData buildLightTheme() => _build(Brightness.light, AppColors.light);

ThemeData buildDarkTheme() => _build(Brightness.dark, AppColors.dark);

ThemeData _build(Brightness brightness, AppColors colors) {
  final textTheme = AppTextThemes.build(colors);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.secondary,
    onSecondary: colors.onAccent,
    tertiary: colors.tertiary,
    onTertiary: colors.onAccent,
    error: colors.error,
    onError: colors.onAccent,
    surface: colors.canvas,
    onSurface: colors.fgPrimary,
    onSurfaceVariant: colors.fgSecondary,
    outline: colors.borderSubtle,
    outlineVariant: colors.borderSubtle,
    surfaceContainerHighest: colors.elevated,
    surfaceContainerHigh: colors.elevated,
    surfaceContainer: colors.elevated,
    surfaceContainerLow: colors.sunken,
    surfaceContainerLowest: colors.sunken,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.canvas,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[colors, PlayerColors.standard],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.canvas,
      foregroundColor: colors.fgPrimary,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: colors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppShapes.borderMd),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(
      color: colors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppShapes.borderSm,
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShapes.borderSm,
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShapes.borderSm,
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppShapes.borderSm,
        borderSide: BorderSide(color: colors.error),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.fgSecondary),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.fgMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: colors.accent.withValues(alpha: 0.4),
        disabledForegroundColor: colors.onAccent.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.borderSm),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.fgPrimary,
        side: BorderSide(color: colors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.borderSm),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.borderSm),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.fgPrimary,
        minimumSize: const Size(40, 40),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.sunken,
      selectedColor: colors.accent.withValues(alpha: 0.16),
      labelStyle: textTheme.labelMedium!,
      side: BorderSide(color: colors.borderSubtle),
      shape: RoundedRectangleBorder(borderRadius: AppShapes.borderFull),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.borderSubtle,
      circularTrackColor: colors.borderSubtle,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.elevated,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.fgPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppShapes.borderMd),
      // Floating inset — slight lift from bottom edge (motion §5.3 spatial cue).
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actionTextColor: colors.accent,
      disabledActionTextColor: colors.fgMuted,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.fgSecondary,
      textColor: colors.fgPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: AppShapes.borderMd),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colors.accent.withValues(alpha: 0.14),
      selectedIconTheme: IconThemeData(color: colors.accent, size: 24),
      unselectedIconTheme: IconThemeData(color: colors.fgSecondary, size: 24),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colors.accent,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colors.fgSecondary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colors.accent.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? colors.accent : colors.fgSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.accent : colors.fgSecondary,
          size: 24,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.accent,
      unselectedLabelColor: colors.fgSecondary,
      indicatorColor: colors.accent,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      dividerColor: colors.borderSubtle,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.borderSubtle,
      thumbColor: colors.accent,
      overlayColor: colors.accent.withValues(alpha: 0.12),
    ),
    focusColor: colors.accent.withValues(alpha: 0.18),
    hoverColor: colors.fgPrimary.withValues(alpha: 0.04),
    splashFactory: InkSparkle.splashFactory,
  );
}
