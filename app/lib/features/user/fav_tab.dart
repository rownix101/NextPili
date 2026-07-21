import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';
import 'library_navigation.dart';
import 'library_video_grid.dart';

/// Favorites folders + resources tab for [UserPage].
class FavTab extends StatefulWidget {
  const FavTab({super.key});

  @override
  State<FavTab> createState() => _FavTabState();
}

class _FavTabState extends State<FavTab> {
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
                          child: LibraryVideoGrid(
                            scroll: _scroll,
                            itemCount: _items.length,
                            loadingMore: _loadingMore,
                            builder: (context, index) {
                              final it = _items[index];
                              final id = libraryVideoRouteId(
                                bvid: it.bvid,
                                aid: i64(it.aid),
                              );
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
                                onTap: () => openLibraryVideo(
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
