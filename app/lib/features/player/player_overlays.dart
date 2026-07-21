import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/player_colors.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'playback_session.dart';
import 'player_pane.dart';

/// Fullscreen + mini hosts for the shared [playbackSessionProvider].
///
/// Mount once under [MaterialApp.router] `builder` so mode switches never
/// dispose the media_kit decoder (progress/audio stay continuous).
class PlayerOverlayLayer extends ConsumerWidget {
  const PlayerOverlayLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playbackSessionProvider);
    final host = session.host;
    final target = session.target;

    // Fullscreen/mini sit above the router navigator (sibling of [child]) and
    // need a local Navigator (which also owns an Overlay) so Tooltips and
    // PopupMenuButton/showMenu work ("No Overlay" / "no Navigator").
    // Mini stays a direct [Positioned] child of this Stack for drag layout.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (host == PlayerSurfaceHost.fullscreen && target != null)
          Positioned.fill(
            child: _OverlayHost(child: _FullscreenHost(target: target)),
          ),
        if (host == PlayerSurfaceHost.mini && target != null)
          _MiniHost(target: target),
      ],
    );
  }
}

/// Local [Navigator] for chrome that lives outside the app router.
///
/// [PopupMenuButton] / [showMenu] push a route and require a [Navigator]
/// ancestor; tooltips only need the [Overlay] that [Navigator] owns.
class _OverlayHost extends StatelessWidget {
  const _OverlayHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: [
        MaterialPage<void>(
          key: const ValueKey<String>('player-overlay-root'),
          child: child,
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

class _FullscreenHost extends ConsumerStatefulWidget {
  const _FullscreenHost({required this.target});

  final PlaybackTarget target;

  @override
  ConsumerState<_FullscreenHost> createState() => _FullscreenHostState();
}

class _FullscreenHostState extends ConsumerState<_FullscreenHost> {
  late final FocusNode _focusNode = FocusNode(debugLabel: 'player.fullscreen');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// True when primary focus is inside an [EditableText] (TextField, etc.).
  ///
  /// Fullscreen media shortcuts must not steal keys while composing / typing
  /// (Latin, digits, Backspace, IME).
  bool get _editingText {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_editingText) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyF) {
      ref.read(playbackSessionProvider.notifier).exitFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    return Material(
      color: Colors.black,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: PlayerPane(
            videoId: target.videoId,
            cid: target.cid,
            aid: target.aid,
            bvid: target.bvid,
            title: target.title,
            qn: target.qn,
            epId: target.epId,
            host: PlayerSurfaceHost.fullscreen,
            immersive: true,
            showBack: true,
            onBack: () {
              ref.read(playbackSessionProvider.notifier).exitFullscreen();
            },
          ),
        ),
      ),
    );
  }
}

class _MiniHost extends ConsumerStatefulWidget {
  const _MiniHost({required this.target});

  final PlaybackTarget target;

  @override
  ConsumerState<_MiniHost> createState() => _MiniHostState();
}

class _MiniHostState extends ConsumerState<_MiniHost> {
  static const _size = Size(320, 180);
  Offset _offset = Offset.zero;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    // Claim mini host without re-opening the stream.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(playbackSessionProvider.notifier).setHost(PlayerSurfaceHost.mini);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    if (!_placed) {
      _offset = Offset(
        size.width - _size.width - 16 - padding.right,
        size.height - _size.height - 24 - padding.bottom,
      );
      _placed = true;
    }

    final maxX =
        (size.width - _size.width - padding.right).clamp(0.0, size.width);
    final maxY =
        (size.height - _size.height - padding.bottom).clamp(0.0, size.height);
    final x = _offset.dx.clamp(padding.left, maxX);
    final y = _offset.dy.clamp(padding.top, maxY);

    // ExcludeFocus: mini's nested Navigator must never hold primary keyboard
    // focus, or main-shell TextFields (search / settings / auth) stop receiving
    // Latin digits / Backspace while mini is open.
    return Positioned(
      left: x,
      top: y,
      width: _size.width,
      height: _size.height,
      child: ExcludeFocus(
        child: _OverlayHost(
          child: GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _offset = Offset(
                  (_offset.dx + d.delta.dx).clamp(padding.left, maxX),
                  (_offset.dy + d.delta.dy).clamp(padding.top, maxY),
                );
              });
            },
            onDoubleTap: () => _restore(context, ref, widget.target),
            child: _MiniChrome(
              target: widget.target,
              onExpand: () => _restore(context, ref, widget.target),
              onClose: () => ref.read(playbackSessionProvider.notifier).close(),
            ),
          ),
        ),
      ),
    );
  }

  void _restore(BuildContext context, WidgetRef ref, PlaybackTarget t) {
    ref.read(playbackSessionProvider.notifier).restoreFromMini();
    if (t.epId > 0) return;
    final path = '/video/${Uri.encodeComponent(t.videoId)}';
    final loc = GoRouterState.of(context).uri.path;
    if (!loc.startsWith('/video/')) {
      context.push(path);
    }
  }
}

class _MiniChrome extends ConsumerWidget {
  const _MiniChrome({
    required this.target,
    required this.onExpand,
    required this.onClose,
  });

  final PlaybackTarget target;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playbackSessionProvider);
    final adapter = ref.read(playbackSessionProvider.notifier).adapterOrNull;
    final colors = PlayerColors.of(context);
    final l10n = context.l10n;
    final owns = session.host == PlayerSurfaceHost.mini &&
        session.target != null &&
        session.target!.sameMedia(target);

    return Material(
      color: Colors.black,
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (session.error != null)
            Center(
              child: IconButton(
                onPressed: () =>
                    ref.read(playbackSessionProvider.notifier).retry(),
                icon: Icon(AppIcons.refresh, color: colors.controlFg),
                tooltip: l10n.retry,
              ),
            )
          else if (!owns ||
              session.loading ||
              adapter == null)
            const AppLoading()
          else
            Video(
              controller: adapter.controller,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: colors.chromeGlass,
              child: Row(
                children: [
                  if (adapter != null)
                    StreamBuilder<bool>(
                      stream: adapter.player.stream.playing,
                      initialData: adapter.player.state.playing,
                      builder: (context, snap) {
                        final playing = snap.data ?? false;
                        return NpIconButton(
                          icon: playing ? AppIcons.pause : AppIcons.play,
                          color: colors.controlFg,
                          onPressed: () {
                            if (playing) {
                              adapter.pause();
                            } else {
                              adapter.play();
                            }
                          },
                          tooltip: playing ? l10n.pause : l10n.play,
                        );
                      },
                    ),
                  Expanded(
                    child: Text(
                      target.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.controlFg, fontSize: 12),
                    ),
                  ),
                  NpIconButton(
                    icon: AppIcons.fullscreen,
                    color: colors.controlFg,
                    onPressed: onExpand,
                    tooltip: l10n.playerRestore,
                  ),
                  NpIconButton(
                    icon: AppIcons.close,
                    color: colors.controlFg,
                    onPressed: onClose,
                    tooltip: l10n.playerClose,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
