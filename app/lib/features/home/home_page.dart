import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/adaptive/window_size.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass/app_glass.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final padH = AppSpacing.pagePaddingH(width);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              padH,
              AppSpacing.sm,
              padH,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassSegmentedControl(
                  segments: [
                    GlassSegment(label: l10n.homeTabRecommend),
                    GlassSegment(label: l10n.homeTabPopular),
                    GlassSegment(label: l10n.homeTabRegion),
                  ],
                  selectedIndex: _tab,
                  onSegmentSelected: (i) => setState(() => _tab = i),
                  selectedTextStyle: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: colors.fgPrimary),
                  unselectedTextStyle: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: colors.fgSecondary),
                  quality: GlassQuality.standard,
                  useOwnLayer: true,
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _RecommendFeedTab(),
                _PopularFeedTab(),
                _RegionFeedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendFeedTab extends StatefulWidget {
  const _RecommendFeedTab();

  @override
  State<_RecommendFeedTab> createState() => _RecommendFeedTabState();
}

class _RecommendFeedTabState extends State<_RecommendFeedTab> {
  final _items = <FeedItemDto>[];
  final _scroll = ScrollController();
  int _freshIdx = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || _error != null) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await CoreApi.instance.feedRecommend(freshIdx: 0, ps: 12);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _freshIdx = page.nextFreshIdx;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await CoreApi.instance.feedRecommend(freshIdx: _freshIdx, ps: 12);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _freshIdx = page.nextFreshIdx;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FeedBody(
      items: _items,
      scrollController: _scroll,
      loading: _loading,
      loadingMore: _loadingMore,
      error: _error,
      onRetry: _refresh,
      onRefresh: _refresh,
    );
  }
}

class _PopularFeedTab extends StatefulWidget {
  const _PopularFeedTab();

  @override
  State<_PopularFeedTab> createState() => _PopularFeedTabState();
}

class _PopularFeedTabState extends State<_PopularFeedTab> {
  final _items = <FeedItemDto>[];
  final _scroll = ScrollController();
  int _pn = 1;
  bool _noMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || _noMore || _error != null) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _noMore = false;
    });
    try {
      final page = await CoreApi.instance.feedPopular(pn: 1, ps: 20);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _pn = page.nextPn;
        _noMore = page.noMore || page.items.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _noMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.feedPopular(pn: _pn, ps: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pn = page.nextPn;
        _noMore = page.noMore || page.items.isEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FeedBody(
      items: _items,
      scrollController: _scroll,
      loading: _loading,
      loadingMore: _loadingMore,
      error: _error,
      onRetry: _refresh,
      onRefresh: _refresh,
    );
  }
}

class _RegionFeedTab extends StatefulWidget {
  const _RegionFeedTab();

  @override
  State<_RegionFeedTab> createState() => _RegionFeedTabState();
}

class _RegionFeedTabState extends State<_RegionFeedTab> {
  final _items = <FeedItemDto>[];
  final _scroll = ScrollController();
  List<RegionDto> _regions = const [];
  int _rid = 0;
  bool _loadingRegions = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _loadingRegions = true;
      _error = null;
    });
    try {
      final regions = await CoreApi.instance.feedRegions();
      if (!mounted) return;
      final rid = regions.isNotEmpty ? regions.first.rid : 0;
      setState(() {
        _regions = regions;
        _rid = rid;
        _loadingRegions = false;
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRegions = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _selectRid(int rid) async {
    if (rid == _rid && _items.isNotEmpty) return;
    setState(() => _rid = rid);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await CoreApi.instance.feedRanking(rid: _rid);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final padH = AppSpacing.pagePaddingH(width);

    if (_loadingRegions && _regions.isEmpty) {
      return const Center(child: AppLoading());
    }
    if (_error != null && _regions.isEmpty) {
      return EmptyState.error(message: _error!, onRetry: _loadRegions);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: padH,
              vertical: AppSpacing.sm,
            ),
            itemCount: _regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final region = _regions[index];
              final selected = region.rid == _rid;
              return FilterChip(
                selected: selected,
                label: Text(region.name),
                onSelected: (_) => _selectRid(region.rid),
                selectedColor: colors.accent.withValues(alpha: 0.22),
                checkmarkColor: colors.accent,
              );
            },
          ),
        ),
        Expanded(
          child: _FeedBody(
            items: _items,
            scrollController: _scroll,
            loading: _loading,
            loadingMore: false,
            error: _error,
            onRetry: _reload,
            onRefresh: _reload,
            emptyMessage: l10n.emptyContent,
          ),
        ),
      ],
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.items,
    required this.scrollController,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.onRetry,
    required this.onRefresh,
    this.emptyMessage,
  });

  final List<FeedItemDto> items;
  final ScrollController scrollController;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final String? emptyMessage;

  SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(int cross) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cross,
      mainAxisSpacing: AppSpacing.md - 4,
      crossAxisSpacing: AppSpacing.md - 4,
      childAspectRatio: 16 / 13,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final padH = AppSpacing.pagePaddingH(width);

    if (loading && items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final contentW = (constraints.maxWidth - padH * 2)
              .clamp(0.0, AppSpacing.contentMaxWidth);
          final cross = videoGridCrossAxisCount(contentW);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(padH, 0, padH, AppSpacing.md),
            gridDelegate: _gridDelegate(cross),
            itemCount: cross * 2,
            itemBuilder: (_, _) => const VideoCardSkeleton(),
          );
        },
      );
    }
    if (error != null && items.isEmpty) {
      return EmptyState.error(
        message: error!,
        onRetry: onRetry,
        secondaryLabel: l10n.goLogin,
        onSecondary: () => context.push('/auth'),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentW = (constraints.maxWidth - padH * 2)
              .clamp(0.0, AppSpacing.contentMaxWidth);
          final cross = videoGridCrossAxisCount(contentW);
          return CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padH, 0, padH, AppSpacing.md),
                sliver: SliverGrid(
                  gridDelegate: _gridDelegate(cross),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      final id = item.bvid.isNotEmpty
                          ? item.bvid
                          : 'av${i64(item.aid)}';
                      final heroTag =
                          AppHeroTags.videoCover(id, slot: index);
                      return VideoCard(
                        title: item.title,
                        coverUrl: item.cover,
                        ownerName: item.ownerName,
                        durationLabel:
                            formatDurationMs(i64(item.durationMs)),
                        heroTag: heroTag,
                        onTap: () {
                          context.push(
                            '/video/${Uri.encodeComponent(id)}',
                            extra: heroTag,
                          );
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
              if (loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: AppLoading(size: 24),
                  ),
                ),
              if (!loadingMore && items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(message: emptyMessage ?? l10n.emptyContent),
                ),
            ],
          );
        },
      ),
    );
  }
}
