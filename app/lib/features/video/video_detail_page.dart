import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_themes.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
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

/// Desktop-first watch page — interaction §4.0 + design-system content rules.
///
/// Layout: player · engagement · title/meta · desc · comments | UP · parts · related.
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

    final headerTitle = async.maybeWhen(
      data: (d) => d.title.isNotEmpty ? d.title : l10n.videoWatchTitle,
      orElse: () => l10n.videoWatchTitle,
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: headerTitle,
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
        // design-system §8.7 — skeleton preferred over bare spinner.
        loading: () => const _WatchSkeleton(),
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
  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final videoId = widget.videoId;
    final currentCid = widget.currentCid;
    final onSelectCid = widget.onSelectCid;
    final padH = AppSpacing.pagePaddingH(MediaQuery.sizeOf(context).width);

    return LayoutBuilder(
      builder: (context, constraints) {
        // interaction §4.0 — dual column when content ≥ 960.
        // Player stays sticky above the scroll region so comments never tear
        // down the surface (progress/audio keep running).
        final wide = constraints.maxWidth >= 960;
        final player = _PlayerBlock(
          detail: detail,
          videoId: videoId,
          cid: currentCid,
        );
        final rail = _RightRail(
          detail: detail,
          currentCid: currentCid,
          onSelect: (p) => onSelectCid(i64(p.cid)),
        );
        final below = _BelowPlayer(detail: detail);

        if (wide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _StickyPlayerColumn(
                    maxHeight: constraints.maxHeight - AppSpacing.md,
                    player: player,
                    body: [
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

        // Narrow: sticky player + scroll body (engagement → title → rail → comments).
        return Padding(
          padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, 0),
          child: _StickyPlayerColumn(
            maxHeight: constraints.maxHeight - AppSpacing.md,
            player: player,
            body: [
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
          ),
        );
      },
    );
  }
}

/// Sticky 16:9 player + scrollable body; shrinks player when height is tight
/// (multi-platform §3.1 short windows).
class _StickyPlayerColumn extends StatelessWidget {
  const _StickyPlayerColumn({
    required this.maxHeight,
    required this.player,
    required this.body,
  });

  final double maxHeight;
  final Widget player;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) {
    // Leave room for engagement/title so the Column never overflows.
    // multi-platform §3.1: short windows shrink the player, keep body scrollable.
    double playerMaxH = double.infinity;
    if (maxHeight.isFinite && maxHeight > 0) {
      final reserve = maxHeight < 280 ? 72.0 : 96.0;
      final upper = (maxHeight - reserve).clamp(120.0, maxHeight);
      final preferred = maxHeight * 0.62;
      playerMaxH = preferred.clamp(120.0, upper);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: playerMaxH),
          child: player,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: body,
          ),
        ),
      ],
    );
  }
}

class _PlayerBlock extends StatelessWidget {
  const _PlayerBlock({
    required this.detail,
    required this.videoId,
    required this.cid,
  });

  final VideoDetailDto detail;
  final String videoId;
  final int cid;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (cid <= 0) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: AppShapes.borderMd,
          child: ColoredBox(
            color: colors.sunken,
            child: detail.cover.isEmpty
                ? Icon(AppIcons.imageBroken, color: colors.fgMuted, size: 40)
                : Image.network(detail.cover, fit: BoxFit.cover),
          ),
        ),
      );
    }

    // Align letterboxes when height is capped by [_StickyPlayerColumn].
    return ClipRRect(
      borderRadius: AppShapes.borderMd,
      child: ColoredBox(
        color: colors.sunken,
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
          ),
        ),
      ),
    );
  }
}

/// Title + meta — design-system §5.2 `type.title` / §5.3 2-line title.
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
    final idLabel =
        detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.title,
          style: theme.textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MetaItem(
              icon: AppIcons.play,
              label:
                  '${l10n.statView} ${formatCount(i64(stat.view), locale: locale)}',
            ),
            _MetaItem(
              icon: AppIcons.danmaku,
              label:
                  '${l10n.statDanmaku} ${formatCount(i64(stat.danmaku), locale: locale)}',
            ),
            _MetaItem(
              icon: AppIcons.comment,
              label:
                  '${l10n.statReply} ${formatCount(i64(stat.reply), locale: locale)}',
            ),
            Text(
              idLabel,
              style: AppTextThemes.meta(context, color: colors.fgMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lightweight meta row (type.meta) — not heavy chips on the watch page.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIcons.xs, color: colors.fgSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextThemes.meta(context),
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
        const _RelatedPlaceholder(),
      ],
    );
  }
}

/// Related list shell — interaction §4.0 placeholder until `video_related`.
class _RelatedPlaceholder extends StatelessWidget {
  const _RelatedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return ContentSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
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
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.videoDesc, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ExpandableDesc(
          text: detail.desc.isEmpty ? l10n.videoDescEmpty : detail.desc,
          empty: detail.desc.isEmpty,
        ),
        const SizedBox(height: AppSpacing.lg),
        ReplySection(aid: i64(detail.aid)),
      ],
    );
  }
}

/// Description: max 3 lines + expand — design-system §5.3.
class _ExpandableDesc extends StatefulWidget {
  const _ExpandableDesc({required this.text, required this.empty});

  final String text;
  final bool empty;

  @override
  State<_ExpandableDesc> createState() => _ExpandableDescState();
}

class _ExpandableDescState extends State<_ExpandableDesc> {
  bool _expanded = false;
  bool _overflows = false;

  @override
  void didUpdateWidget(covariant _ExpandableDesc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
      _overflows = false;
    }
  }

  void _measureOverflow(double maxWidth, TextStyle? style) {
    if (widget.empty) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 3,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final next = painter.didExceedMaxLines;
    if (next != _overflows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _overflows = next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: widget.empty ? colors.fgMuted : colors.fgSecondary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _measureOverflow(constraints.maxWidth, style);
        final canToggle = _overflows && !widget.empty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.empty || !_expanded)
              Text(
                widget.text,
                style: style,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
            else
              SelectableText(widget.text, style: style),
            if (canToggle) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(_expanded ? l10n.collapse : l10n.expand),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// First-paint skeleton matching dual-column watch layout.
class _WatchSkeleton extends StatelessWidget {
  const _WatchSkeleton();

  @override
  Widget build(BuildContext context) {
    final padH = AppSpacing.pagePaddingH(MediaQuery.sizeOf(context).width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final player = AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonBox(
            height: double.infinity,
            borderRadius: AppShapes.borderMd,
          ),
        );
        final leftMeta = <Widget>[
          const SkeletonBox(height: 40, width: double.infinity),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 22, width: 280),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 14, width: 200),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: 14, width: 64),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 48, width: double.infinity),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 48, width: double.infinity),
        ];
        final rail = Column(
          children: [
            SkeletonBox(
              height: 72,
              width: double.infinity,
              borderRadius: AppShapes.borderMd,
            ),
            const SizedBox(height: AppSpacing.md),
            SkeletonBox(
              height: 160,
              width: double.infinity,
              borderRadius: AppShapes.borderMd,
            ),
          ],
        );

        if (wide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _StickyPlayerColumn(
                    maxHeight: constraints.maxHeight - AppSpacing.md,
                    player: player,
                    body: leftMeta,
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

        return Padding(
          padding: EdgeInsets.fromLTRB(padH, AppSpacing.md, padH, 0),
          child: _StickyPlayerColumn(
            maxHeight: constraints.maxHeight - AppSpacing.md,
            player: player,
            body: [
              ...leftMeta,
              const SizedBox(height: AppSpacing.lg),
              rail,
            ],
          ),
        );
      },
    );
  }
}
