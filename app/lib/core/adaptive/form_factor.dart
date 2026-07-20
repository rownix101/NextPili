import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Desktop OS (Linux / Windows / macOS), not web.
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// Phone / tablet OS (Android / iOS), not web.
bool get isMobileOs {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

/// Material tablet threshold (shortest side ≥ 600dp).
bool isTabletLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide >= 600;
}

/// QR login is only for desktop shells and tablet-sized layouts.
///
/// Phones should use SMS (or other non-QR methods).
bool supportsQrLogin(BuildContext context) {
  if (isDesktopPlatform) return true;
  if (isMobileOs && isTabletLayout(context)) return true;
  return false;
}
