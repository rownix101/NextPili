import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../bridge/core_api.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/widgets/glass/glass_panel.dart';
import '../../l10n/l10n.dart';
import 'player_adapter.dart';
import 'player_settings_list.dart';
import 'player_settings_local_state.dart';
import 'player_settings_quality_panel.dart';
import 'player_settings_sleep_panel.dart';
import 'player_settings_speed_panel.dart';
import 'player_settings_subtitle_panel.dart';

/// Preferred width for the right-side settings popover (DESIGN.md §3).
const double kPlayerSettingsPanelWidth = 280;

enum _SettingsSubPanel { list, speed, quality, subtitle, sleep }

/// Right-side player settings panel — Liquid Glass tray over video chrome.
///
/// Package glass (not Flutter [BackdropFilter] over the texture). Speed,
/// quality, subtitle, and sleep use in-panel nested lists (shared options chrome).
/// List body: [PlayerSettingsListBody].
class PlayerSettingsOverlay extends StatefulWidget {
  const PlayerSettingsOverlay({
    super.key,
    required this.colors,
    required this.local,
    required this.onLocalChanged,
    required this.qualityLabel,
    required this.speedLabel,
    required this.currentSpeed,
    required this.subtitleLabel,
    required this.qualities,
    required this.subtitleTracks,
    required this.onQuality,
    required this.onSpeed,
    required this.onSubtitle,
    this.currentQualityId,
    this.currentSubtitleId,
    this.onInteract,
  });

  final PlayerColors colors;
  final PlayerSettingsLocalState local;
  final ValueChanged<PlayerSettingsLocalState> onLocalChanged;
  final String qualityLabel;
  final String speedLabel;
  final double currentSpeed;
  final String subtitleLabel;
  final List<StreamDto> qualities;
  final List<SubtitleTrackDto> subtitleTracks;
  final ValueChanged<StreamDto> onQuality;
  final ValueChanged<double> onSpeed;
  final ValueChanged<SubtitleTrackDto?> onSubtitle;
  final String? currentQualityId;
  final String? currentSubtitleId;
  final VoidCallback? onInteract;

  @override
  State<PlayerSettingsOverlay> createState() => _PlayerSettingsOverlayState();
}

class _PlayerSettingsOverlayState extends State<PlayerSettingsOverlay> {
  _SettingsSubPanel _panel = _SettingsSubPanel.list;

  void _open(_SettingsSubPanel panel) {
    widget.onInteract?.call();
    setState(() => _panel = panel);
  }

  void _closeSubPanel() {
    setState(() => _panel = _SettingsSubPanel.list);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = appMotionDuration(
      context,
      AppDuration.medium1,
      reduced: AppDuration.short2,
    );
    final reduce = appReduceMotion(context);

    return Semantics(
      container: true,
      label: l10n.playerSettings,
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: AppShapes.md),
        settings: GlassPanel.playerChromeSettings(widget.colors.chromeGlass),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 240,
            maxWidth: kPlayerSettingsPanelWidth,
          ),
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: AppEasing.standardDecelerate,
            switchOutCurve: AppEasing.standardAccelerate,
            transitionBuilder: (child, animation) {
              if (reduce) {
                return FadeTransition(opacity: animation, child: child);
              }
              // Pixel [Transform.translate] — not [SlideTransition] /
              // [FractionalTranslation]. The latter asserts
              // `!debugNeedsLayout` when hit-tested mid-relayout (panel
              // swap + shrinkWrap list, or pointer during animation).
              // See flutter/flutter#139070.
              return FadeTransition(
                opacity: animation,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // [animation] is already curved by switchIn/OutCurve.
                    return Transform.translate(
                      offset: Offset(
                        _kSettingsSlidePx * (1 - animation.value),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: child,
                ),
              );
            },
            child: switch (_panel) {
              _SettingsSubPanel.speed => KeyedSubtree(
                  key: const ValueKey('speed'),
                  child: PlayerSettingsSpeedPanel(
                    colors: widget.colors,
                    currentSpeed: widget.currentSpeed,
                    onSpeed: widget.onSpeed,
                    onBack: _closeSubPanel,
                    speedOptions: MediaKitPlayerAdapter.speedOptions,
                    onInteract: widget.onInteract,
                  ),
                ),
              _SettingsSubPanel.quality => KeyedSubtree(
                  key: const ValueKey('quality'),
                  child: PlayerSettingsQualityPanel(
                    colors: widget.colors,
                    qualities: widget.qualities,
                    currentId: widget.currentQualityId,
                    onQuality: widget.onQuality,
                    onBack: _closeSubPanel,
                    onInteract: widget.onInteract,
                  ),
                ),
              _SettingsSubPanel.subtitle => KeyedSubtree(
                  key: const ValueKey('subtitle'),
                  child: PlayerSettingsSubtitlePanel(
                    colors: widget.colors,
                    tracks: widget.subtitleTracks,
                    currentId: widget.currentSubtitleId,
                    onSubtitle: widget.onSubtitle,
                    onBack: _closeSubPanel,
                    onInteract: widget.onInteract,
                  ),
                ),
              _SettingsSubPanel.sleep => KeyedSubtree(
                  key: const ValueKey('sleep'),
                  child: PlayerSettingsSleepPanel(
                    colors: widget.colors,
                    sleepTimerMinutes: widget.local.sleepTimerMinutes,
                    onSelect: (minutes) {
                      widget.onLocalChanged(
                        widget.local.withSleepTimer(minutes),
                      );
                    },
                    onBack: _closeSubPanel,
                    onInteract: widget.onInteract,
                  ),
                ),
              _SettingsSubPanel.list => KeyedSubtree(
                  key: const ValueKey('list'),
                  child: PlayerSettingsListBody(
                    colors: widget.colors,
                    local: widget.local,
                    onLocalChanged: widget.onLocalChanged,
                    qualityLabel: widget.qualityLabel,
                    speedLabel: widget.speedLabel,
                    subtitleLabel: widget.subtitleLabel,
                    onInteract: widget.onInteract,
                    onOpenSubtitle: () => _open(_SettingsSubPanel.subtitle),
                    onOpenSleep: () => _open(_SettingsSubPanel.sleep),
                    onOpenSpeed: () => _open(_SettingsSubPanel.speed),
                    onOpenQuality: () => _open(_SettingsSubPanel.quality),
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// Horizontal slide distance for settings enter/exit and panel swaps.
///
/// Pixel offset (not a width fraction) so we can animate via
/// [Transform.translate] and avoid [RenderFractionalTranslation] hit-test
/// asserts when layout is dirty mid-gesture.
const double _kSettingsSlidePx = 12;

/// Fade + slight slide from the right (DESIGN.md §6).
class PlayerSettingsOverlayHost extends StatelessWidget {
  const PlayerSettingsOverlayHost({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = appMotionDuration(
      context,
      AppDuration.medium2,
      reduced: AppDuration.short2,
    );
    final reduce = appReduceMotion(context);
    final curve = visible
        ? AppEasing.standardDecelerate
        : AppEasing.standardAccelerate;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: curve,
        // [Transform.translate] instead of [AnimatedSlide]: SlideTransition
        // uses FractionalTranslation, which asserts `!debugNeedsLayout` if a
        // pointer hit-tests while the settings tree is dirty (open/close,
        // sub-panel switch, chrome relayout). Transform only needs paint.
        child: reduce
            ? child
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  end: visible ? 0 : _kSettingsSlidePx,
                ),
                duration: duration,
                curve: curve,
                builder: (context, dx, child) {
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: child,
              ),
      ),
    );
  }
}
