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
import '../../l10n/l10n.dart';
import '../player/player_pane.dart';

final pgcSeasonProvider =
    FutureProvider.autoDispose.family<PgcSeasonDto, int>((ref, seasonId) {
  return CoreApi.instance.pgcSeason(seasonId: seasonId);
});

/// Season watch page: player + episode list.
class PgcSeasonPage extends ConsumerStatefulWidget {
  const PgcSeasonPage({
    super.key,
    required this.seasonId,
    this.initialEpId = 0,
  });

  final int seasonId;
  final int initialEpId;

  @override
  ConsumerState<PgcSeasonPage> createState() => _PgcSeasonPageState();
}

class _PgcSeasonPageState extends ConsumerState<PgcSeasonPage> {
  int? _selectedEpId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pgcSeasonProvider(widget.seasonId));
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.pgcTitle,
        showBack: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/pgc');
          }
        },
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => EmptyState.error(
          message: errorMessage(e, context.l10n),
          onRetry: () => ref.invalidate(pgcSeasonProvider(widget.seasonId)),
        ),
        data: (season) {
          final ep = _resolveEp(season);
          return _SeasonBody(
            season: season,
            current: ep,
            onSelect: (e) => setState(() => _selectedEpId = i64(e.epId)),
          );
        },
      ),
    );
  }

  PgcEpisodeDto? _resolveEp(PgcSeasonDto season) {
    if (season.episodes.isEmpty) return null;
    final want = _selectedEpId ??
        (widget.initialEpId > 0
            ? widget.initialEpId
            : i64(season.defaultEpId));
    if (want > 0) {
      for (final e in season.episodes) {
        if (i64(e.epId) == want) return e;
      }
    }
    return season.episodes.first;
  }
}

class _SeasonBody extends StatelessWidget {
  const _SeasonBody({
    required this.season,
    required this.current,
    required this.onSelect,
  });

  final PgcSeasonDto season;
  final PgcEpisodeDto? current;
  final ValueChanged<PgcEpisodeDto> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final ep = current;
    final title = season.seasonTitle.isNotEmpty
        ? season.seasonTitle
        : season.title;

    final player = ep == null
        ? AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  l10n.pgcNoEpisode,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: 16 / 9,
            child: PlayerPane(
              key: ValueKey('ep-${i64(ep.epId)}-${i64(ep.cid)}'),
              videoId: ep.bvid.isNotEmpty ? ep.bvid : 'av${i64(ep.aid)}',
              cid: i64(ep.cid),
              aid: i64(ep.aid),
              bvid: ep.bvid,
              epId: i64(ep.epId),
              title: _epLabel(ep, l10n),
            ),
          );

    final meta = ContentPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              if (season.typeName.isNotEmpty)
                Text(
                  season.typeName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.fgSecondary,
                  ),
                ),
              if (season.ratingScore.isNotEmpty)
                Text(
                  l10n.pgcRating(season.ratingScore),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.accent,
                  ),
                ),
            ],
          ),
          if (ep != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _epLabel(ep, l10n),
              style: theme.textTheme.titleSmall,
            ),
          ],
          if (season.evaluate.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              season.evaluate,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.fgSecondary,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    final eps = _EpisodeList(
      episodes: season.episodes,
      currentEpId: ep != null ? i64(ep.epId) : 0,
      onSelect: onSelect,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: ListView(
              children: [
                player,
                meta,
              ],
            ),
          ),
          VerticalDivider(width: 1, color: colors.borderSubtle),
          SizedBox(
            width: 320,
            child: eps,
          ),
        ],
      );
    }

    return ListView(
      children: [
        player,
        meta,
        const Divider(height: 1),
        eps,
      ],
    );
  }

  String _epLabel(PgcEpisodeDto ep, AppLocalizations l10n) {
    final short = ep.title.isNotEmpty ? ep.title : '';
    final long = ep.longTitle;
    if (short.isNotEmpty && long.isNotEmpty) {
      return l10n.pgcEpisodeLabel(short, long);
    }
    if (long.isNotEmpty) return long;
    if (short.isNotEmpty) return short;
    return l10n.pgcEpisodeFallback(i64(ep.epId).toString());
  }
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({
    required this.episodes,
    required this.currentEpId,
    required this.onSelect,
  });

  final List<PgcEpisodeDto> episodes;
  final int currentEpId;
  final ValueChanged<PgcEpisodeDto> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (episodes.isEmpty) {
      return ContentPad(
        child: Text(
          l10n.pgcNoEpisode,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.fgSecondary,
          ),
        ),
      );
    }

    return ContentPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.movie, size: 18, color: colors.fgSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.pgcEpisodesCount(episodes.length),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final e = episodes[i];
                final epId = i64(e.epId);
                final selected = epId == currentEpId;
                final label = e.longTitle.isNotEmpty
                    ? (e.title.isNotEmpty
                        ? '${e.title}  ${e.longTitle}'
                        : e.longTitle)
                    : (e.title.isNotEmpty
                        ? e.title
                        : l10n.pgcEpisodeFallback('$epId'));
                final dur = formatDurationMs(i64(e.durationMs));
                return Material(
                  color: selected
                      ? colors.accent.withValues(alpha: 0.12)
                      : colors.elevated,
                  borderRadius: AppShapes.borderSm,
                  child: InkWell(
                    borderRadius: AppShapes.borderSm,
                    onTap: () => onSelect(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight:
                                    selected ? FontWeight.w600 : null,
                                color: selected
                                    ? colors.accent
                                    : colors.fgPrimary,
                              ),
                            ),
                          ),
                          if (e.badge.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              e.badge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.live,
                              ),
                            ),
                          ],
                          if (dur.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              dur,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.fgMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
