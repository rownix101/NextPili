import 'package:flutter/material.dart';

import 'desktop_window.dart';

/// Syncs system backdrop dark mode (Windows DWM / macOS VisualEffect) with [Theme].
///
/// Place once under [MaterialApp] so theme toggles update the system backdrop.
/// Linux transparent has no dark flag — no-op there.
class DesktopBackdropSync extends StatefulWidget {
  const DesktopBackdropSync({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopBackdropSync> createState() => _DesktopBackdropSyncState();
}

class _DesktopBackdropSyncState extends State<DesktopBackdropSync> {
  Brightness? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_applied == brightness) return;
    _applied = brightness;
    // ignore: discarded_futures
    DesktopWindow.syncBrightness(brightness);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
