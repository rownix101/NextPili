import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';

/// Personal library: history · watch later · favorites.
class UserPage extends ConsumerStatefulWidget {
  const UserPage({super.key});

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.navLibrary,
        actions: [
          NpIconButton(
            tooltip: l10n.account,
            icon: AppIcons.user,
            onPressed: () => context.push('/auth'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.libraryTabHistory),
            Tab(text: l10n.libraryTabToview),
            Tab(text: l10n.libraryTabFav),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _HistoryTab(),
          _ToViewTab(),
          _FavTab(),
        ],
      ),
    );
  }
}

String _videoRouteId({required String bvid, required int aid}) {
  final id = bvid.isNotEmpty ? bvid : 'av$aid';
  if (id == 'av0' || id.isEmpty) return '';
  return id;
}

void _openVideo(
  BuildContext context, {
  required String bvid,
  required int aid,
  Object? heroTag,
}) {
  final id = _videoRouteId(bvid: bvid, aid: aid);
  if (id.isEmpty) return;
  context.push(
    '/video/${Uri.encodeComponent(id)}',
    extra: heroTag,
  );
}

// ─── History ────────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _scroll = ScrollController();
  final _items = <HistoryItemDto>[];
  int _nextMax = 0;
  int _nextViewAt = 0;
  String _nextBusiness = '';
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextMax = 0;
      _nextViewAt = 0;
      _nextBusiness = '';
      _hasMore = true;
    });
    try {
      final page = await CoreApi.instance.historyList();
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextMax = i64(page.nextMax);
        _nextViewAt = i64(page.nextViewAt);
        _nextBusiness = page.nextBusiness;
        _hasMore = page.hasMore;
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
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.historyList(
        max: _nextMax,
        viewAt: _nextViewAt,
        business: _nextBusiness,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextMax = i64(page.nextMax);
        _nextViewAt = i64(page.nextViewAt);
        _nextBusiness = page.nextBusiness;
        _hasMore = page.hasMore && page.items.isNotEmpty;
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
    final l10n = context.l10n;
    if (_loading && _items.isEmpty) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return EmptyState(message: l10n.libraryHistoryEmpty);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: _VideoGrid(
        scroll: _scroll,
        itemCount: _items.length,
        loadingMore: _loadingMore,
        builder: (context, index) {
          final it = _items[index];
          final id = _videoRouteId(bvid: it.bvid, aid: i64(it.aid));
          final heroTag =
              id.isEmpty ? null : AppHeroTags.videoCover(id, slot: index);
          return VideoCard(
            title: it.title,
            coverUrl: it.cover,
            ownerName: it.ownerName,
            durationLabel: formatDurationMs(i64(it.durationMs)),
            viewLabel: it.showTitle.isNotEmpty ? it.showTitle : it.ownerName,
            heroTag: heroTag,
            onTap: () => _openVideo(
              context,
              bvid: it.bvid,
              aid: i64(it.aid),
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }
}

// ─── Watch later ────────────────────────────────────────────────────────────

class _ToViewTab extends StatefulWidget {
  const _ToViewTab();

  @override
  State<_ToViewTab> createState() => _ToViewTabState();
}

class _ToViewTabState extends State<_ToViewTab> {
  final _scroll = ScrollController();
  final _items = <ToViewItemDto>[];
  int _pn = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _pn = 1;
      _hasMore = true;
    });
    try {
      final page = await CoreApi.instance.toviewList(pn: 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pn = page.pn;
        _hasMore = page.hasMore;
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
    if (_loadingMore || !_hasMore) return;
    final next = _pn + 1;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.toviewList(pn: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pn = page.pn > 0 ? page.pn : next;
        _hasMore = page.hasMore && page.items.isNotEmpty;
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
    final l10n = context.l10n;
    if (_loading && _items.isEmpty) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return EmptyState(message: l10n.libraryToviewEmpty);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: _VideoGrid(
        scroll: _scroll,
        itemCount: _items.length,
        loadingMore: _loadingMore,
        builder: (context, index) {
          final it = _items[index];
          final id = _videoRouteId(bvid: it.bvid, aid: i64(it.aid));
          final heroTag =
              id.isEmpty ? null : AppHeroTags.videoCover(id, slot: index);
          return VideoCard(
            title: it.title,
            coverUrl: it.cover,
            ownerName: it.ownerName,
            durationLabel: formatDurationMs(i64(it.durationMs)),
            heroTag: heroTag,
            onTap: () => _openVideo(
              context,
              bvid: it.bvid,
              aid: i64(it.aid),
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }
}

// ─── Favorites ──────────────────────────────────────────────────────────────

class _FavTab extends StatefulWidget {
  const _FavTab();

  @override
  State<_FavTab> createState() => _FavTabState();
}

class _FavTabState extends State<_FavTab> {
  List<FavFolderDto> _folders = const [];
  FavFolderDto? _selected;
  final _items = <FavResourceItemDto>[];
  final _scroll = ScrollController();
  int _pn = 1;
  bool _hasMore = true;
  bool _loadingFolders = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFolders();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || !_hasMore || _selected == null) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loadingFolders = true;
      _error = null;
    });
    try {
      final list = await CoreApi.instance.favFolders();
      if (!mounted) return;
      final folders = list.folders;
      setState(() {
        _folders = folders;
        _loadingFolders = false;
        _selected = folders.isNotEmpty ? folders.first : null;
      });
      if (folders.isNotEmpty) {
        await _reloadResources(folders.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFolders = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _reloadResources(FavFolderDto folder) async {
    setState(() {
      _selected = folder;
      _loading = true;
      _error = null;
      _items.clear();
      _pn = 1;
      _hasMore = true;
    });
    try {
      final page = await CoreApi.instance.favResources(
        mediaId: i64(folder.id),
        pn: 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pn = page.pn;
        _hasMore = page.hasMore;
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
    final folder = _selected;
    if (folder == null || _loadingMore || !_hasMore) return;
    final next = _pn + 1;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.favResources(
        mediaId: i64(folder.id),
        pn: next,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pn = page.pn > 0 ? page.pn : next;
        _hasMore = page.hasMore && page.items.isNotEmpty;
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
    final l10n = context.l10n;
    final colors = AppColors.of(context);

    if (_loadingFolders && _folders.isEmpty) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_error != null && _folders.isEmpty) {
      return EmptyState.error(message: _error!, onRetry: _loadFolders);
    }
    if (_folders.isEmpty) {
      return EmptyState(message: l10n.libraryFavEmpty);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: _folders.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final f = _folders[i];
              final selected = _selected?.id == f.id;
              return FilterChip(
                selected: selected,
                label: Text('${f.title} (${f.mediaCount})'),
                onSelected: (_) => _reloadResources(f),
                selectedColor: colors.accent.withValues(alpha: 0.22),
                checkmarkColor: colors.accent,
              );
            },
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: AppLoading(size: 28))
              : _error != null && _items.isEmpty
                  ? EmptyState.error(
                      message: _error!,
                      onRetry: () {
                        final f = _selected;
                        if (f != null) _reloadResources(f);
                      },
                    )
                  : _items.isEmpty
                      ? EmptyState(message: l10n.libraryFavEmpty)
                      : RefreshIndicator(
                          onRefresh: () async {
                            final f = _selected;
                            if (f != null) await _reloadResources(f);
                          },
                          child: _VideoGrid(
                            scroll: _scroll,
                            itemCount: _items.length,
                            loadingMore: _loadingMore,
                            builder: (context, index) {
                              final it = _items[index];
                              final id =
                                  _videoRouteId(bvid: it.bvid, aid: i64(it.aid));
                              final heroTag = id.isEmpty
                                  ? null
                                  : AppHeroTags.videoCover(id, slot: index);
                              return VideoCard(
                                title: it.title,
                                coverUrl: it.cover,
                                ownerName: it.ownerName,
                                durationLabel:
                                    formatDurationMs(i64(it.durationMs)),
                                heroTag: heroTag,
                                onTap: () => _openVideo(
                                  context,
                                  bvid: it.bvid,
                                  aid: i64(it.aid),
                                  heroTag: heroTag,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

// ─── Shared grid ────────────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.scroll,
    required this.itemCount,
    required this.builder,
    this.loadingMore = false,
  });

  final ScrollController scroll;
  final int itemCount;
  final bool loadingMore;
  final Widget Function(BuildContext context, int index) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = _crossAxisCount(constraints.maxWidth);
        return CustomScrollView(
          controller: scroll,
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
                  builder,
                  childCount: itemCount,
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
          ],
        );
      },
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
