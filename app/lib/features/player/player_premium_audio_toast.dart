import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/spacing.dart';
import '../../l10n/l10n.dart';

/// Brief bottom-left notice when Dolby Atmos / Hi-Res audio is active.
///
/// Real blur: optional [frostFrame] (player screenshot) + [ImageFiltered].
/// [BackdropFilter] alone cannot sample media_kit hardware video textures.
class PlayerPremiumAudioToast extends StatefulWidget {
  const PlayerPremiumAudioToast({
    super.key,
    required this.role,
    required this.visible,
    this.frostFrame,
  });

  /// Stream role: `dolby` or `hires`.
  final String role;
  final bool visible;

  /// JPEG/PNG frame from the player for frosted background blur.
  final Uint8List? frostFrame;

  static bool isPremiumRole(String? role) =>
      role == 'dolby' || role == 'hires';

  @override
  State<PlayerPremiumAudioToast> createState() =>
      _PlayerPremiumAudioToastState();
}

class _PlayerPremiumAudioToastState extends State<PlayerPremiumAudioToast>
    with TickerProviderStateMixin {
  static const _spectrum = <Color>[
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF3B30),
  ];

  late final AnimationController _shimmer;
  late final AnimationController _presence;

  @override
  void initState() {
    super.initState();
    // Loop ambient — not UI response latency; longer than AppDuration.long*.
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _presence = AnimationController(
      vsync: this,
      duration: AppDuration.medium1,
      reverseDuration: AppDuration.short3,
      value: widget.visible ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant PlayerPremiumAudioToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _syncAnimations();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _syncAnimations() {
    if (!mounted) return;
    final reduce = appReduceMotion(context);

    if (widget.visible) {
      if (reduce) {
        _presence.value = 1;
      } else {
        _presence.forward();
      }
      if (!reduce && !_shimmer.isAnimating) {
        _shimmer.repeat();
      }
    } else {
      if (reduce) {
        _presence.value = 0;
      } else {
        _presence.reverse();
      }
      if (_shimmer.isAnimating || _shimmer.value != 0) {
        _shimmer
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (widget.role) {
      'dolby' => l10n.playerAudioDolbyOn,
      'hires' => l10n.playerAudioHiresOn,
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();

    final reduce = appReduceMotion(context);

    // Slide/scale only — Opacity ancestors disable BackdropFilter.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _presence,
        builder: (context, child) {
          final raw = _presence.value;
          // Enter decelerate, leave accelerate — motion.md §3.
          final t = _presence.status == AnimationStatus.reverse
              ? AppEasing.standardAccelerate.transform(raw)
              : AppEasing.standardDecelerate.transform(raw);
          if (t <= 0.001) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: Transform.scale(
                  alignment: Alignment.bottomLeft,
                  scale: 0.96 + 0.04 * t,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: _FrostedChip(
          label: label,
          reduceMotion: reduce,
          shimmer: _shimmer,
          spectrum: _spectrum,
          frostFrame: widget.frostFrame,
        ),
      ),
    );
  }
}

class _FrostedChip extends StatelessWidget {
  const _FrostedChip({
    required this.label,
    required this.reduceMotion,
    required this.shimmer,
    required this.spectrum,
    required this.frostFrame,
  });

  final String label;
  final bool reduceMotion;
  final AnimationController shimmer;
  final List<Color> spectrum;
  final Uint8List? frostFrame;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(10));

    final text = reduceMotion
        ? _RainbowText(text: label, shift: 0, colors: spectrum)
        : AnimatedBuilder(
            animation: shimmer,
            builder: (context, _) {
              return _RainbowText(
                text: label,
                shift: shimmer.value,
                colors: spectrum,
              );
            },
          );

    final frame = frostFrame;
    final hasFrame = frame != null && frame.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Sampled player frame — real Gaussian blur over video content.
            if (hasFrame)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: reduceMotion ? 10 : 16,
                    sigmaY: reduceMotion ? 10 : 16,
                    tileMode: TileMode.clamp,
                  ),
                  child: Image.memory(
                    frame,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomLeft,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            // Best-effort live backdrop (works for Flutter-painted layers only).
            if (!hasFrame)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            // Frost tint + edge so text stays readable.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: hasFrame ? 0.16 : 0.20),
                    const Color(0xFF2C2C2E).withValues(
                      alpha: hasFrame ? 0.38 : 0.50,
                    ),
                    const Color(0xFF1C1C1E).withValues(
                      alpha: hasFrame ? 0.48 : 0.58,
                    ),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RainbowText extends StatelessWidget {
  const _RainbowText({
    required this.text,
    required this.shift,
    required this.colors,
  });

  final String text;
  final double shift;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
          tileMode: TileMode.repeated,
          transform: _SlideGradient(shift: shift),
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient({required this.shift});

  final double shift;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * shift, 0, 0);
  }
}
