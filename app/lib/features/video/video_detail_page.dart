import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/stat_chip.dart';
import '../../l10n/l10n.dart';
import 'reply_section.dart';

final videoDetailProvider =
    FutureProvider.autoDispose.family<VideoDetailDto, String>((ref, id) {
  return CoreApi.instance.videoDetail(id);
});

class VideoDetailPage extends ConsumerWidget {
  const VideoDetailPage({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoDetailProvider(videoId));
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.videoDetailTitle,
        showBack: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => EmptyState.error(
          message: errorMessage(e, context.l10n),
          onRetry: () => ref.invalidate(videoDetailProvider(videoId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final VideoDetailDto detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final cover = _Cover(url: detail.cover);
        final info = _InfoColumn(detail: detail);

        final replies = ReplySection(aid: i64(detail.aid));

        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    children: [
                      cover,
                      const SizedBox(height: AppSpacing.lg),
                      replies,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 6, child: SingleChildScrollView(child: info)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: cover),
            const SizedBox(height: AppSpacing.md),
            info,
            const SizedBox(height: AppSpacing.lg),
            replies,
          ],
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: AppShapes.borderMd,
      child: url.isEmpty
          ? ColoredBox(
              color: colors.sunken,
              child: Icon(AppIcons.movie, size: AppIcons.xl, color: colors.fgMuted),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, error, stackTrace) => ColoredBox(
                color: colors.sunken,
                child: Icon(
                  AppIcons.imageBroken,
                  size: AppIcons.xl,
                  color: colors.fgMuted,
                ),
              ),
            ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.detail});

  final VideoDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final stat = detail.stat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.fgSecondary),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.sunken,
              backgroundImage: detail.ownerFace.isNotEmpty
                  ? NetworkImage(detail.ownerFace)
                  : null,
              child: detail.ownerFace.isEmpty
                  ? Icon(AppIcons.user, size: 18, color: colors.fgSecondary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                detail.ownerName,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            StatChip(
              icon: AppIcons.play,
              label: formatCount(i64(stat.view), locale: locale),
            ),
            StatChip(
              icon: AppIcons.like,
              label: formatCount(i64(stat.like), locale: locale),
            ),
            StatChip(
              icon: AppIcons.comment,
              label: formatCount(i64(stat.reply), locale: locale),
            ),
            StatChip(
              icon: AppIcons.danmaku,
              label: formatCount(i64(stat.danmaku), locale: locale),
            ),
            StatChip(
              icon: AppIcons.star,
              label: formatCount(i64(stat.favorite), locale: locale),
            ),
            StatChip(
              icon: AppIcons.coin,
              label: formatCount(i64(stat.coin), locale: locale),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.videoDesc, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs + 2),
        SelectableText(
          detail.desc.isEmpty ? l10n.videoDescEmpty : detail.desc,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg - 4),
        Text(
          l10n.videoPartsCount(detail.pages.length),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (detail.pages.isEmpty)
          Text(
            l10n.videoPartsEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.fgSecondary,
            ),
          )
        else
          ...detail.pages.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: colors.sunken,
                child: Text(
                  '${p.page}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              title: Text(
                p.part_.isEmpty ? l10n.videoPartFallback(p.page) : p.part_,
              ),
              subtitle: Text(
                'cid ${i64(p.cid)} · ${formatDurationMs(i64(p.durationMs), emptyAsZero: true)}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Icon(AppIcons.playCircle, color: colors.accent),
              onTap: () => _openPlayer(context, detail, i64(p.cid)),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        NpButton(
          label: l10n.play,
          icon: AppIcons.play,
          onPressed: detail.pages.isEmpty
              ? null
              : () => _openPlayer(context, detail, i64(detail.pages.first.cid)),
        ),
      ],
    );
  }
}

void _openPlayer(BuildContext context, VideoDetailDto detail, int cid) {
  final id = detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}';
  final title = Uri.encodeComponent(detail.title);
  final bvid = Uri.encodeComponent(detail.bvid);
  context.push(
    '/play/${Uri.encodeComponent(id)}'
    '?cid=$cid&aid=${i64(detail.aid)}&bvid=$bvid&title=$title',
  );
}
