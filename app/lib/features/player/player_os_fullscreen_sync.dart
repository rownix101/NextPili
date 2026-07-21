import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/adaptive/desktop_window.dart';
import 'playback_session.dart';

/// Aligns [PlaybackSession] host when the user leaves OS fullscreen via the
/// system (gesture, WM shortcut, native chrome) rather than the in-app control.
///
/// Mount once under [MaterialApp.router] `builder` (desktop only registers).
class PlayerOsFullscreenSync extends ConsumerStatefulWidget {
  const PlayerOsFullscreenSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlayerOsFullscreenSync> createState() =>
      _PlayerOsFullscreenSyncState();
}

class _PlayerOsFullscreenSyncState extends ConsumerState<PlayerOsFullscreenSync>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    if (DesktopWindow.isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (DesktopWindow.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowLeaveFullScreen() {
    final host = ref.read(playbackSessionProvider).host;
    if (host != PlayerSurfaceHost.fullscreen) return;
    ref.read(playbackSessionProvider.notifier).exitFullscreen();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
