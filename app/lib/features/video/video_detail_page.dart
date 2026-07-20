import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/content_pad.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/stat_chip.dart';
import '../../l10n/l10n.dart';
import '../player/player_pane.dart';
import 'engagement_bar.dart';
import 'owner_card.dart';
import 'parts_panel.dart';
import 'reply_section.dart';

final videoDetailProvider =
    FutureProvider.autoDispose.family<VideoDetailDto, String>((ref, id) {
  return CoreApi.instance.videoDetail(id);
});

/// Desktop-first watch page modeled on bilibili web layout:
/// player + engagement + comments on the left; UP + parts on the right.
class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.videoId,
    this.initialCid = 0,
  });

  final String videoId;
  final int initialCid;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  int? _selectedCid;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(videoDetailProvider(widget.videoId));
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.videoWatchTitle,
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
          onRetry: () => ref.invalidate(videoDetailProvider(widget.videoId)),
        ),
        data: (detail) {
          final cid = _resolveCid(detail);
          return _WatchBody(
            detail: detail,
            videoId: widget.videoId,
            currentCid: cid,
            onSelectCid: (c) => setState(() => _selectedCid = c),
          );
        },
      ),
    );
  }

  int _resolveCid(VideoDetailDto detail) {
    if (_selectedCid != null && _selectedCid! > 0) return _selectedCid!;
    if (widget.initialCid > 0) return widget.initialCid;
    if (detail.pages.isNotEmpty) return i64(detail.pages.first.cid);
    return 0;
  }
}

class _WatchBody extends StatefulWidget {
  const _WatchBody({
    required this.detail,
    required this.videoId,
    required this.currentCid,
    required this.onSelectCid,
  });

  final VideoDetailDto detail;
  final String videoId;
  final int currentCid;
  final ValueChanged<int> onSelectCid;

  @override
  State<_WatchBody> createState() => _WatchBodyState();
}

class _WatchBodyState extends State<_WatchBody> {
  /// Hide embedded player while immersive `/play` is open (one decoder).
  bool _immersiveOpen = false;

  Future<void> _openFullscreen() async {
    final detail = widget.detail;
    final title = Uri.encodeComponent(detail.title);
    final bvid = Uri.encodeComponent(detail.bvid);
    setState(() => _immersiveOpen = true);
    await context.push(
      '/play/${Uri.encodeComponent(widget.videoId)}'
      '?cid=${widget.currentCid}&aid=${i64(detail.aid)}&bvid=$bvid&title=$title',
    );
    if (mounted) setState(() => _immersiveOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final videoId = widget.videoId;
    final currentCid = widget.currentCid;
    final onSelectCid = widget.onSelectCid;
    final padH = AppSpacing.pagePaddingH(MediaQuery.sizeOf(context).width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final player = _PlayerBlock(
          detail: detail,
          videoId: videoId,
          cid: currentCid,
          suspended: _immersiveOpen,
          onFullscreen: _openFullscreen,
        );
        final rail = _RightRail(
          detail: detail,
          currentCid: currentCid,
          onSelect: (p) => onSelectCid(i64(p.cid)),
        );
        final below = _BelowPlayer(
          detail: detail,
        );

        if (wide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [
                      player,
                      EngagementBar(
                        aid: i64(detail.aid),
                        bvid: detail.bvid,
                        stat: detail.stat,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _TitleBlock(detail: detail),
                      const SizedBox(height: AppSpacing.md),
                      below,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [rail],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, AppSpacing.xl),
          children: [
            player,
            EngagementBar(
              aid: i64(detail.aid),
              bvid: detail.bvid,
              stat: detail.stat,
            ),
            const SizedBox(height: AppSpacing.md),
            _TitleBlock(detail: detail),
            const SizedBox(height: AppSpacing.md),
            rail,
            const SizedBox(height: AppSpacing.lg),
            below,
          ],
        );
      },
    );
  }
}

class _PlayerBlock extends StatelessWidget {
  const _PlayerBlock({
    required this.detail,
    required this.videoId,
    required this.cid,
    required this.suspended,
    required this.onFullscreen,
  });

  final VideoDetailDto detail;
  final String videoId;
  final int cid;
  final bool suspended;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget cover() => ColoredBox(
          color: colors.sunken,
          child: detail.cover.isEmpty
              ? Icon(AppIcons.imageBroken, color: colors.fgMuted, size: 40)
              : Image.network(detail.cover, fit: BoxFit.cover),
        );

    if (cid <= 0 || suspended) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: AppShapes.borderMd,
          child: cover(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppShapes.borderMd,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: PlayerPane(
          key: ValueKey('pane-$videoId-$cid'),
          videoId: videoId,
          cid: cid,
          aid: i64(detail.aid),
          bvid: detail.bvid,
          title: detail.title,
          immersive: false,
          onRequestFullscreen: onFullscreen,
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.detail});

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
        Text(detail.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            StatChip(
              icon: AppIcons.play,
              label:
                  '${l10n.statView} ${formatCount(i64(stat.view), locale: locale)}',
            ),
            StatChip(
              icon: AppIcons.danmaku,
              label:
                  '${l10n.statDanmaku} ${formatCount(i64(stat.danmaku), locale: locale)}',
            ),
            StatChip(
              icon: AppIcons.comment,
              label:
                  '${l10n.statReply} ${formatCount(i64(stat.reply), locale: locale)}',
            ),
            Text(
              detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.fgMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.detail,
    required this.currentCid,
    required this.onSelect,
  });

  final VideoDetailDto detail;
  final int currentCid;
  final ValueChanged<VideoPageDto> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerCard(detail: detail),
        const SizedBox(height: AppSpacing.md),
        PartsPanel(
          pages: detail.pages,
          currentCid: currentCid,
          onSelect: onSelect,
        ),
        const SizedBox(height: AppSpacing.md),
        _RelatedPlaceholder(),
      ],
    );
  }
}

class _RelatedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return ContentPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.videoRelated, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.actionComingSoon,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.fgMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BelowPlayer extends StatelessWidget {
  const _BelowPlayer({required this.detail});

  final VideoDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.videoDesc, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs + 2),
        SelectableText(
          detail.desc.isEmpty ? l10n.videoDescEmpty : detail.desc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.fgSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ReplySection(aid: i64(detail.aid)),
      ],
    );
  }
}
