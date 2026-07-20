import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';

/// Live recommend feed (REST).
class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  final _scroll = ScrollController();
  final _items = <LiveRoomCardDto>[];
  int _page = 1;
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
      _page = 1;
      _hasMore = true;
    });
    try {
      final page = await CoreApi.instance.liveRecommend(page: 1, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _page = 2;
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
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await CoreApi.instance.liveRecommend(page: _page, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _page += 1;
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

  void _openRoom(LiveRoomCardDto it) {
    final id = i64(it.roomId);
    if (id <= 0) return;
    context.push('/live/$id');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(title: l10n.liveTitle),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _items.isEmpty) {
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
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(
        message: _error!,
        onRetry: _reload,
      );
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
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: aSliverGrid(
                  cross: cross,
                  l10n: l10n,
                ),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: AppLoading(size: 24),
                  ),
                ),
              if (!_loadingMore && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: l10n.liveEmpty,
                    icon: AppIcons.live,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget aSliverGrid({
    required int cross,
    required AppLocalizations l10n,
  }) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: AppSpacing.md - 4,
        crossAxisSpacing: AppSpacing.md - 4,
        childAspectRatio: 16 / 13,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final it = _items[index];
          final online = i64(it.online);
          return VideoCard(
            title: it.title,
            coverUrl: it.cover,
            ownerName: it.uname.isNotEmpty
                ? it.uname
                : (it.areaName.isNotEmpty ? it.areaName : l10n.live),
            durationLabel: '',
            viewLabel:
                online > 0 ? l10n.liveOnline(formatCount(online)) : '',
            live: true,
            onTap: () => _openRoom(it),
          );
        },
        childCount: _items.length,
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
