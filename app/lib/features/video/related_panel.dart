import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_themes.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/loading.dart';
import '../../l10n/l10n.dart';
import '../user/library_navigation.dart';

/// Related archives for the watch-page right rail — interaction §4.0.
///
/// Compact horizontal rows (cover · title · UP · duration). Opaque content
/// surface, not glass — design-system §2 / §8.2.
final videoRelatedProvider =
    FutureProvider.autoDispose.family<List<FeedItemDto>, String>((ref, id) {
  return CoreApi.instance.videoRelated(id);
});

class RelatedPanel extends ConsumerWidget {
  const RelatedPanel({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final async = ref.watch(videoRelatedProvider(videoId));

    return ContentSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.videoRelated, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const Column(
              children: [
                _RelatedRowSkeleton(),
                SizedBox(height: AppSpacing.sm),
                _RelatedRowSkeleton(),
                SizedBox(height: AppSpacing.sm),
                _RelatedRowSkeleton(),
              ],
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage(e, l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.fgMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(videoRelatedProvider(videoId)),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.retry),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  l10n.emptyContent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.fgMuted,
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  return _RelatedRow(
                    item: items[i],
                    slot: i,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.item, required this.slot});

  final FeedItemDto item;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final reduceMotion = appReduceMotion(context);
    final aid = i64(item.aid);
    final routeId = libraryVideoRouteId(bvid: item.bvid, aid: aid);
    if (routeId.isEmpty) return const SizedBox.shrink();

    final duration = formatDurationMs(i64(item.durationMs));
    final heroTag = AppHeroTags.videoCover(routeId, slot: 'related-$slot');

    Widget cover = ClipRRect(
      borderRadius: AppShapes.borderSm,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: item.cover.isEmpty
            ? ColoredBox(
                color: colors.sunken,
                child: Icon(AppIcons.movie, color: colors.fgMuted, size: 20),
              )
            : Image.network(
                item.cover,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => ColoredBox(
                  color: colors.sunken,
                  child: Icon(
                    AppIcons.imageBroken,
                    color: colors.fgMuted,
                    size: 20,
                  ),
                ),
              ),
      ),
    );

    if (!reduceMotion) {
      cover = Hero(
        tag: heroTag,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: cover,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppShapes.borderSm,
        hoverColor: colors.fgPrimary.withValues(alpha: 0.04),
        focusColor: colors.accent.withValues(alpha: 0.12),
        onTap: () {
          Haptics.selection();
          context.push(
            '/video/${Uri.encodeComponent(routeId)}',
            extra: heroTag,
          );
        },
        child: Semantics(
          button: true,
          label: item.title,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 128, child: cover),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          if (item.ownerName.isNotEmpty) item.ownerName,
                          if (duration.isNotEmpty) duration,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextThemes.meta(context),
                      ),
                    ],
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

class _RelatedRowSkeleton extends StatelessWidget {
  const _RelatedRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(
          width: 128,
          height: 72,
          borderRadius: AppShapes.borderSm,
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 14, width: double.infinity),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 14, width: 160),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 12, width: 96),
            ],
          ),
        ),
      ],
    );
  }
}
