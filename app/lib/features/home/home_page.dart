import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: 'NextPili',
        actions: [
          NpIconButton(
            tooltip: '账号',
            icon: AppIcons.user,
            onPressed: () => context.push('/auth'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '热门'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RecommendFeedTab(),
          _PopularFeedTab(),
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
        _error = errorMessage(e);
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
        SnackBar(content: Text(errorMessage(e))),
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
        _error = errorMessage(e);
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
        SnackBar(content: Text(errorMessage(e))),
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

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.items,
    required this.scrollController,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.onRetry,
    required this.onRefresh,
  });

  final List<FeedItemDto> items;
  final ScrollController scrollController;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cross = _crossAxisCount(constraints.maxWidth);
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: AppSpacing.md - 4,
              crossAxisSpacing: AppSpacing.md - 4,
              childAspectRatio: 16 / 13,
            ),
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
        secondaryLabel: '去登录',
        onSecondary: () => context.push('/auth'),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cross = _crossAxisCount(constraints.maxWidth);
          return CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.md - 4,
                    crossAxisSpacing: AppSpacing.md - 4,
                    childAspectRatio: 16 / 13,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return VideoCard(
                        title: item.title,
                        coverUrl: item.cover,
                        ownerName: item.ownerName,
                        durationLabel: _formatDuration(i64(item.durationMs)),
                        onTap: () {
                          final id = item.bvid.isNotEmpty
                              ? item.bvid
                              : 'av${i64(item.aid)}';
                          context.push('/video/${Uri.encodeComponent(id)}');
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
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(message: '暂无内容'),
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

String _formatDuration(int ms) {
  if (ms <= 0) return '';
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}
