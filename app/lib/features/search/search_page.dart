import 'dart:async';

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
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _items = <SearchVideoItemDto>[];

  Timer? _suggestDebounce;
  List<String> _suggests = const [];
  String _activeKeyword = '';
  int _page = 1;
  int _numPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _showSuggest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final term = _controller.text.trim();
    setState(() {}); // refresh clear button
    _suggestDebounce?.cancel();
    if (term.isEmpty) {
      setState(() {
        _suggests = const [];
        _showSuggest = false;
      });
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadSuggest(term);
    });
  }

  Future<void> _loadSuggest(String term) async {
    try {
      final res = await CoreApi.instance.searchSuggest(term: term);
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _suggests = res.terms;
        _showSuggest = _focus.hasFocus && res.terms.isNotEmpty;
      });
    } catch (_) {
      // Suggest failures are non-fatal.
    }
  }

  void _onScroll() {
    if (_loadingMore || _loading || _error != null) return;
    if (_page >= _numPages && _numPages > 0) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _submit([String? raw]) async {
    final keyword = (raw ?? _controller.text).trim();
    if (keyword.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _controller.text = keyword;
      _controller.selection = TextSelection.collapsed(offset: keyword.length);
      _activeKeyword = keyword;
      _showSuggest = false;
      _loading = true;
      _error = null;
      _page = 1;
      _numPages = 1;
      _items.clear();
    });
    try {
      final page =
          await CoreApi.instance.searchVideo(keyword: keyword, page: 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        _numPages = page.numPages > 0 ? page.numPages : 1;
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
    if (_loadingMore || _loading || _activeKeyword.isEmpty) return;
    final next = _page + 1;
    if (_numPages > 0 && next > _numPages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance
          .searchVideo(keyword: _activeKeyword, page: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page > 0 ? page.page : next;
        if (page.numPages > 0) _numPages = page.numPages;
        if (page.items.isEmpty) _numPages = _page;
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
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.searchTitle,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              onTap: () {
                if (_suggests.isNotEmpty) {
                  setState(() => _showSuggest = true);
                }
              },
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.cancel,
                        icon: const Icon(AppIcons.close),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _items.clear();
                            _activeKeyword = '';
                            _error = null;
                            _suggests = const [];
                            _showSuggest = false;
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colors.elevated.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (_showSuggest && _suggests.isNotEmpty)
            Material(
              color: colors.elevated.withValues(alpha: 0.92),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggests.length,
                  itemBuilder: (context, i) {
                    final term = _suggests[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(AppIcons.search, size: AppIcons.sm),
                      title: Text(term),
                      onTap: () => _submit(term),
                    );
                  },
                ),
              ),
            ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _items.isEmpty) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(
        message: _error!,
        onRetry: () => _submit(_activeKeyword),
      );
    }
    if (_activeKeyword.isEmpty && _items.isEmpty) {
      return EmptyState(message: l10n.searchIdle);
    }
    if (!_loading && _items.isEmpty) {
      return EmptyState(message: l10n.searchEmpty);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = _crossAxisCount(constraints.maxWidth);
        return CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_activeKeyword.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    l10n.searchResultHint(_activeKeyword),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
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
                    final item = _items[index];
                    final locale = Localizations.localeOf(context);
                    final id = item.bvid.isNotEmpty
                        ? item.bvid
                        : 'av${i64(item.aid)}';
                    final heroTag = AppHeroTags.videoCover(id, slot: index);
                    return VideoCard(
                      title: item.title,
                      coverUrl: item.cover,
                      ownerName: item.ownerName,
                      durationLabel: formatDurationMs(i64(item.durationMs)),
                      viewLabel: formatCount(i64(item.play), locale: locale),
                      heroTag: heroTag,
                      onTap: () {
                        context.push(
                          '/video/${Uri.encodeComponent(id)}',
                          extra: heroTag,
                        );
                      },
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
            if (_loadingMore)
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
