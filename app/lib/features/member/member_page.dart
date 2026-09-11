import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/hero_tags.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';
import '../video/engagement_bar.dart' show ensureLoggedIn;

/// Member (UP) space page: profile header + contribution grid.
class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key, required this.mid});

  final int mid;

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  final _scroll = ScrollController();
  final _videos = <MemberVideoItemDto>[];

  MemberProfileDto? _profile;
  int _nextAid = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool? _followOverride;
  String? _error;
  String _order = 'pubdate';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || !_hasMore || _error != null) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    if (widget.mid <= 0) {
      setState(() {
        _loading = false;
        _error = context.l10n.errorGeneric;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _followOverride = null;
    });
    try {
      final results = await Future.wait<Object>([
        CoreApi.instance.memberProfile(widget.mid),
        CoreApi.instance.memberVideos(mid: widget.mid, order: _order),
      ]);
      final profile = results[0] as MemberProfileDto;
      final page = results[1] as MemberVideoPageDto;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _videos
          ..clear()
          ..addAll(page.items);
        _nextAid = i64(page.nextAid);
        _total = i64(page.total);
        _hasMore = page.hasMore && _nextAid > 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = errorMessage(e, context.l10n);
      if (_profile == null) {
        setState(() {
          _loading = false;
          _error = message;
        });
      } else {
        setState(() => _loading = false);
        AppSnackBar.show(context, message: message);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _nextAid <= 0) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.memberVideos(
        mid: widget.mid,
        aid: _nextAid,
        order: _order,
      );
      if (!mounted) return;
      setState(() {
        _videos.addAll(page.items);
        _nextAid = i64(page.nextAid);
        _hasMore = page.hasMore && _nextAid > 0;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
    final currently = _followOverride ?? _profile?.isFollowing ?? false;
    final next = !currently;
    setState(() {
      _busy = true;
      _followOverride = next;
    });
    try {
      await CoreApi.instance.relationFollow(mid: widget.mid, follow: next);
      await Haptics.impactLight();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: next
            ? context.l10n.followSuccess
            : context.l10n.unfollowSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _followOverride = currently);
      await Haptics.error();
      if (!mounted) return;
      AppSnackBar.show(context, message: errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openVideo(MemberVideoItemDto item, int index) {
    final aid = i64(item.aid);
    final id = item.bvid.isNotEmpty ? item.bvid : 'av$aid';
    final cid = i64(item.cid);
    final heroTag = AppHeroTags.videoCover(
      id,
      slot: 'member-${widget.mid}-$index',
    );
    final path = cid > 0
        ? '/video/${Uri.encodeComponent(id)}?cid=$cid'
        : '/video/${Uri.encodeComponent(id)}';
    context.push(path, extra: heroTag);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final title = profile?.name.isNotEmpty == true
        ? profile!.name
        : context.l10n.memberProfileFallback;
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: PageHeader(
        title: title,
        showBack: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _profile == null) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_error != null && _profile == null) {
      return EmptyState.error(message: _error!, onRetry: _reload);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cross = _crossAxisCount(constraints.maxWidth);
          return CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: _ProfileCard(
                    profile: _profile!,
                    following: _followOverride ?? _profile!.isFollowing,
                    busy: _busy,
                    onToggleFollow: _toggleFollow,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: context.l10n.memberTabVideos,
                  count: _total,
                  order: _order,
                  onOrderChanged: (order) {
                    if (order == _order) return;
                    setState(() => _order = order);
                    _reload();
                  },
                ),
              ),
              if (_videos.isEmpty && !_loading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(message: context.l10n.memberVideosEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.md - 4,
                      crossAxisSpacing: AppSpacing.md - 4,
                      childAspectRatio: 16 / 13,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= _videos.length) {
                        return const Center(child: AppLoading(size: 24));
                      }
                      final item = _videos[index];
                      final locale = Localizations.localeOf(context);
                      final id = item.bvid.isNotEmpty
                          ? item.bvid
                          : 'av${i64(item.aid)}';
                      return VideoCard(
                        title: item.title,
                        coverUrl: item.cover,
                        ownerName: item.author,
                        durationLabel: formatDurationMs(i64(item.durationMs)),
                        viewLabel: formatCount(i64(item.play), locale: locale),
                        heroTag: AppHeroTags.videoCover(
                          id,
                          slot: 'member-${widget.mid}-$index',
                        ),
                        onTap: () => _openVideo(item, index),
                      );
                    }, childCount: _videos.length + (_loadingMore ? 1 : 0)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 520) return 2;
    return 1;
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.following,
    required this.busy,
    required this.onToggleFollow,
  });

  final MemberProfileDto profile;
  final bool following;
  final bool busy;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final face = profile.face;
    final sign = profile.sign.trim();
    final official = profile.officialTitle.trim();

    return ContentSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colors.sunken,
                backgroundImage: face.isNotEmpty ? NetworkImage(face) : null,
                child: face.isEmpty
                    ? Icon(
                        AppIcons.user,
                        size: AppIcons.lg,
                        color: colors.fgMuted,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.level > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _LevelBadge(level: profile.level),
                        ],
                      ],
                    ),
                    if (sign.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sign,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.fgSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (official.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(AppIcons.shield, size: 14, color: colors.info),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              official,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.info,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(
                label: l10n.memberStatFans,
                value: formatCount(i64(profile.fans), locale: locale),
              ),
              const SizedBox(width: AppSpacing.lg),
              _Stat(
                label: l10n.memberStatFollowing,
                value: formatCount(i64(profile.following), locale: locale),
              ),
              const SizedBox(width: AppSpacing.lg),
              _Stat(
                label: l10n.memberStatLikes,
                value: formatCount(i64(profile.likes), locale: locale),
              ),
              const Spacer(),
              if (!profile.isSelf)
                NpButton(
                  label: following ? l10n.following : l10n.follow,
                  icon: following ? AppIcons.check : AppIcons.plus,
                  loading: busy,
                  variant: following
                      ? NpButtonVariant.secondary
                      : NpButtonVariant.primary,
                  onPressed: busy ? null : onToggleFollow,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.14),
        borderRadius: AppShapes.borderXs,
      ),
      child: Text(
        context.l10n.memberLevel(level),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.accent),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(color: colors.fgPrimary),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: colors.fgMuted),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.order,
    required this.onOrderChanged,
  });

  final String title;
  final int count;
  final String order;
  final ValueChanged<String> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.memberVideosCount(formatCount(count, locale: locale)),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.fgMuted),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: title,
            initialValue: order,
            onSelected: onOrderChanged,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pubdate',
                child: Text(context.l10n.memberVideosSortLatest),
              ),
              PopupMenuItem(
                value: 'click',
                child: Text(context.l10n.memberVideosSortPopular),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                AppIcons.sliders,
                size: AppIcons.sm,
                color: colors.fgSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
