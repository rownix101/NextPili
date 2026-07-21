import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/form_factor.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/glass/mobile_glass_tab_bar.dart';
import '../../l10n/l10n.dart';
import 'playback_session.dart';

/// Apple Music–style now-playing glass pill for **mobile** mini host.
///
/// Sits above [MobileGlassTabBar] (design-system §2.5 floating play pill).
/// Desktop mini keeps the video PiP in [PlayerOverlayLayer].
///
/// Tap empty area → restore watch page; play/pause & close absorb their hits.
class MiniPlayerPill extends ConsumerWidget {
  const MiniPlayerPill({super.key, required this.target});

  final PlaybackTarget target;

  void _restore(BuildContext context, WidgetRef ref) {
    ref.read(playbackSessionProvider.notifier).restoreFromMini();
    if (target.epId > 0) return;
    final path = '/video/${Uri.encodeComponent(target.videoId)}';
    final loc = GoRouterState.of(context).uri.path;
    if (!loc.startsWith('/video/')) {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop / tablet compact use PiP mini — do not paint this pill.
    if (!isMobileOs) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final adapter = ref.read(playbackSessionProvider.notifier).adapterOrNull;
    final h = MobileGlassTabBar.miniPillHeight;
    final bottom = MobileGlassTabBar.miniPillBottom(context);

    return Positioned(
      left: MobileGlassTabBar.outerHPad,
      right: MobileGlassTabBar.outerHPad,
      bottom: bottom,
      height: h,
      child: ExcludeFocus(
        child: Semantics(
          container: true,
          label: target.title.isEmpty ? l10n.playerMini : target.title,
          child: GlassButton.custom(
            onTap: () => _restore(context, ref),
            label: l10n.playerRestore,
            quality: GlassQuality.standard,
            useOwnLayer: true,
            width: double.infinity,
            height: h,
            shape: LiquidRoundedSuperellipse(borderRadius: h / 2),
            settings: MobileGlassTabBar.pillSettings(colors),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _CoverThumb(accent: colors.accent),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      target.title.isEmpty ? l10n.playerMini : target.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.fgPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                    ),
                  ),
                  if (adapter != null)
                    StreamBuilder<bool>(
                      stream: adapter.player.stream.playing,
                      initialData: adapter.player.state.playing,
                      builder: (context, snap) {
                        final playing = snap.data ?? false;
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          tooltip: playing ? l10n.pause : l10n.play,
                          onPressed: () {
                            if (playing) {
                              adapter.pause();
                            } else {
                              adapter.play();
                            }
                          },
                          icon: Icon(
                            playing ? AppIcons.pause : AppIcons.play,
                            size: AppIcons.md,
                            color: colors.fgPrimary,
                          ),
                        );
                      },
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 40,
                    ),
                    tooltip: l10n.playerClose,
                    onPressed: () {
                      ref.read(playbackSessionProvider.notifier).close();
                    },
                    icon: Icon(
                      AppIcons.close,
                      size: AppIcons.sm,
                      color: colors.fgSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.85),
              accent.withValues(alpha: 0.35),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.playCircle,
          size: AppIcons.sm,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
