import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../motion/app_motion.dart';
import '../theme/app_colors.dart';
import '../theme/shapes.dart';
import '../theme/spacing.dart';
import '../theme/text_themes.dart';
import 'content_surface.dart';

/// Opaque feed video card — design-system §8.2 (no GlassCard).
///
/// Pass [heroTag] (via [AppHeroTags.videoCover]) when opening `/video/:id`
/// so the cover can container-transform into the watch page (motion §4.4).
class VideoCard extends StatefulWidget {
  const VideoCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.onTap,
    this.ownerName = '',
    this.durationLabel = '',
    this.viewLabel = '',
    this.live = false,
    this.qualityBadge,
    this.heroTag,
  });

  final String title;
  final String coverUrl;
  final String ownerName;
  final String durationLabel;
  final String viewLabel;
  final bool live;
  final String? qualityBadge;

  /// Stable cover [Hero] tag; null disables morph (live / non-video targets).
  final Object? heroTag;
  final VoidCallback onTap;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final reduceMotion = appReduceMotion(context);
    final micro = reduceMotion ? Duration.zero : AppDuration.short2;

    final scale = reduceMotion
        ? 1.0
        : (_pressed
            ? 0.98
            : (_hover ? 1.02 : 1.0));

    Widget cover = Stack(
      fit: StackFit.expand,
      children: [
        _Cover(url: widget.coverUrl, reduceMotion: reduceMotion),
        if (widget.live)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: _Badge(
              label: context.l10n.live,
              color: colors.live,
            ),
          ),
        if (widget.qualityBadge != null)
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _Badge(
              label: widget.qualityBadge!,
              color: colors.fgPrimary.withValues(alpha: 0.72),
            ),
          ),
        if (widget.durationLabel.isNotEmpty)
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _Badge(
              label: widget.durationLabel,
              color: colors.fgPrimary.withValues(alpha: 0.72),
            ),
          ),
        // Always mounted so hover mask can fade (no teleport).
        AnimatedOpacity(
          opacity: _hover ? 1 : 0,
          duration: micro,
          curve: AppEasing.standardDecelerate,
          child: IgnorePointer(
            child: ColoredBox(
              color: colors.fgPrimary.withValues(alpha: 0.18),
              child: Center(
                child: Icon(
                  AppIcons.playCircle,
                  size: AppIcons.xl,
                  color: colors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.heroTag != null && !reduceMotion) {
      cover = Hero(
        tag: widget.heroTag!,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: cover,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: micro,
          curve: AppEasing.standardDecelerate,
          child: ContentSurface(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: cover,
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 2,
                      AppSpacing.sm,
                      AppSpacing.sm + 2,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Text(
                          [
                            if (widget.ownerName.isNotEmpty) widget.ownerName,
                            if (widget.viewLabel.isNotEmpty) widget.viewLabel,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextThemes.meta(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppShapes.borderXs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.of(context).onAccent,
            ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.reduceMotion});

  final String url;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (url.isEmpty) {
      return ColoredBox(
        color: colors.sunken,
        child: Icon(AppIcons.movie, color: colors.fgMuted),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => ColoredBox(
        color: colors.sunken,
        child: Icon(AppIcons.imageBroken, color: colors.fgMuted),
      ),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (reduceMotion || wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: frame == null ? Duration.zero : AppDuration.medium1,
          curve: AppEasing.standardDecelerate,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        // Keep placeholder under fading image so load → content is not a hard cut.
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: colors.sunken,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
