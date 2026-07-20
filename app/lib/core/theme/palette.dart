import 'package:flutter/material.dart';

/// Locked color constants from docs/ux/design-system.md §3.
/// Business code must read via [AppColors] ThemeExtension, not these raw values.
abstract final class Palette {
  // Accent (Sky — not Bilibili pink / official blue)
  static const accentLight = Color(0xFF0284C7);
  static const accentDark = Color(0xFF38BDF8);
  static const onAccentLight = Color(0xFFFFFFFF);
  static const onAccentDark = Color(0xFF0B0F1A);

  static const secondaryLight = Color(0xFF4F46E5);
  static const secondaryDark = Color(0xFF818CF8);
  static const tertiaryLight = Color(0xFF7C3AED);
  static const tertiaryDark = Color(0xFFA78BFA);

  // Backgrounds
  static const canvasLight = Color(0xFFF4F6FA);
  static const canvasDark = Color(0xFF0B0F1A);
  static const elevatedLight = Color(0xFFFFFFFF);
  static const elevatedDark = Color(0xFF121826);
  static const sunkenLight = Color(0xFFE8ECF4);
  static const sunkenDark = Color(0xFF070A12);

  // Foreground
  static const fgPrimaryLight = Color(0xFF0F172A);
  static const fgPrimaryDark = Color(0xFFF8FAFC);
  static const fgSecondaryLight = Color(0xFF475569);
  static const fgSecondaryDark = Color(0xFF94A3B8);
  static const fgMuted = Color(0xFF64748B);

  // Borders
  static const borderSubtleLight = Color(0xFFE2E8F0);
  static const borderSubtleDark = Color(0xFF1F2937);
  static const borderStrongLight = Color(0xFFCBD5E1);
  static const borderStrongDark = Color(0xFF334155);

  // Status
  static const errorLight = Color(0xFFDC2626);
  static const errorDark = Color(0xFFF87171);
  static const successLight = Color(0xFF16A34A);
  static const successDark = Color(0xFF4ADE80);
  static const warningLight = Color(0xFFD97706);
  static const warningDark = Color(0xFFFBBF24);
  static const infoLight = accentLight;
  static const infoDark = accentDark;
  static const liveLight = Color(0xFFEF4444);
  static const liveDark = Color(0xFFF87171);
  static const vipLight = Color(0xFFCA8A04);
  static const vipDark = Color(0xFFEAB308);

  // Glass tint (alpha = stain strength)
  static const glassTintNeutralLight = Color(0x1AFFFFFF);
  static const glassTintNeutralDark = Color(0x73121826);
  static const glassTintChromeLight = Color(0x24FFFFFF);
  static const glassTintChromeDark = Color(0x8C0F172A);
  static const glassTintAccentLight = Color(0x240284C7);
  static const glassTintAccentDark = Color(0x2938BDF8);
  static const glassTintPlayer = Color(0x59000000);
}
