import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('NextPili'),
        actions: [
          IconButton(
            tooltip: '账号',
            icon: const Icon(Icons.person_outline),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/auth'),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cross = width >= 1400
              ? 5
              : width >= 1100
                  ? 4
                  : width >= 800
                      ? 3
                      : width >= 520
                          ? 2
                          : 1;
          return CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 16 / 13,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return _FeedCard(
                        item: item,
                        onTap: () {
                          final id =
                              item.bvid.isNotEmpty ? item.bvid : 'av${i64(item.aid)}';
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
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (!loadingMore && items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('暂无内容')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.onTap});

  final FeedItemDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _formatDuration(i64(item.durationMs));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverImage(url: item.cover),
                  if (duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          duration,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      item.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.movie_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: theme.colorScheme.surfaceContainerHigh,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
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
