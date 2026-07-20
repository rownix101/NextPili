import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildLightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
  );
}

ThemeData buildDarkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
  );
}
