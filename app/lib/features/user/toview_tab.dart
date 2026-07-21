import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/motion/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';
import 'library_navigation.dart';
import 'library_video_grid.dart';

/// Watch-later list tab for [UserPage].
class ToViewTab extends StatefulWidget {
  const ToViewTab({super.key});

  @override
  State<ToViewTab> createState() => _ToViewTabState();
}

class _ToViewTabState extends State<ToViewTab> {
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
      child: LibraryVideoGrid(
        scroll: _scroll,
        itemCount: _items.length,
        loadingMore: _loadingMore,
        builder: (context, index) {
          final it = _items[index];
          final id = libraryVideoRouteId(bvid: it.bvid, aid: i64(it.aid));
          final heroTag =
              id.isEmpty ? null : AppHeroTags.videoCover(id, slot: index);
          return VideoCard(
            title: it.title,
            coverUrl: it.cover,
            ownerName: it.ownerName,
            durationLabel: formatDurationMs(i64(it.durationMs)),
            heroTag: heroTag,
            onTap: () => openLibraryVideo(
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
