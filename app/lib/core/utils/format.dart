import 'dart:ui' show Locale;

/// Locale-aware count abbreviation (docs/ux/localization.md §4.1).
String formatCount(int n, {Locale? locale}) {
  final lang = locale?.languageCode ?? 'zh';
  if (lang.startsWith('zh')) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(1)}亿';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return '$n';
  }
  if (n >= 1000000000) {
    return '${(n / 1000000000).toStringAsFixed(1)}B';
  }
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}K';
  }
  return '$n';
}

/// Progress / duration labels: `m:ss` or `h:mm:ss` (docs/ux/localization.md §4.2).
String formatDurationMs(int ms, {bool emptyAsZero = false}) {
  if (ms <= 0) return emptyAsZero ? '0:00' : '';
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}
