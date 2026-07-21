// Discrete playback-speed index helpers (DESIGN.md §5.1).
// Slider domain is option index, not raw rate. Canonical options live on
// MediaKitPlayerAdapter.speedOptions — callers pass that list in.

/// Index of [rate] in [options] (exact, else nearest; ties → lower index).
int playerSpeedOptionIndex(double rate, List<double> options) {
  if (options.isEmpty) return 0;
  var best = 0;
  var bestDist = (options[0] - rate).abs();
  for (var i = 0; i < options.length; i++) {
    if (options[i] == rate) return i;
    final d = (options[i] - rate).abs();
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

/// Neighbor rate after stepping [delta] discrete steps, or `null` if clamped out.
double? playerSpeedStepRate(
  double rate,
  List<double> options, {
  required int delta,
}) {
  if (options.isEmpty || delta == 0) return null;
  final i = playerSpeedOptionIndex(rate, options);
  final next = i + delta;
  if (next < 0 || next >= options.length) return null;
  return options[next];
}
