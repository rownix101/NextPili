import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';

/// Follow dynamics (read-only).
class DynamicsPage extends ConsumerStatefulWidget {
  const DynamicsPage({super.key});

  @override
  ConsumerState<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends ConsumerState<DynamicsPage> {
  final _scroll = ScrollController();
  final _items = <DynamicItemDto>[];
  String _offset = '';
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _needLogin = false;

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
      _needLogin = false;
      _items.clear();
      _offset = '';
      _page = 1;
      _hasMore = true;
    });
    try {
      final page = await CoreApi.instance.dynamicsFeed();
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset = page.nextOffset;
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _page = 2;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final login = e is AppError && e.kind == ErrorKind.unauthenticated;
      setState(() {
        _loading = false;
        _needLogin = login;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.dynamicsFeed(
        offset: _offset,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset = page.nextOffset;
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

  void _openItem(DynamicItemDto it) {
    final bvid = it.bvid;
    final aid = i64(it.aid);
    final id = bvid.isNotEmpty ? bvid : (aid > 0 ? 'av$aid' : '');
    if (id.isEmpty) return;
    context.push('/video/${Uri.encodeComponent(id)}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.dynamicsTitle,
        actions: [
          NpIconButton(
            tooltip: l10n.account,
            icon: AppIcons.user,
            onPressed: () => context.push('/auth'),
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _items.isEmpty) {
      return const Center(child: AppLoading(size: 28));
    }
    if (_needLogin && _items.isEmpty) {
      return EmptyState.error(
        message: l10n.dynamicsNeedLogin,
        onRetry: () => context.push('/auth'),
        retryLabel: l10n.goLogin,
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(
        message: _error!,
        onRetry: _reload,
        secondaryLabel: l10n.goLogin,
        onSecondary: () => context.push('/auth'),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(message: l10n.dynamicsEmpty);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: AppLoading(size: 24)),
            );
          }
          final it = _items[index];
          return _DynamicCard(
            item: it,
            onTap: () => _openItem(it),
          );
        },
      ),
    );
  }
}

class _DynamicCard extends StatelessWidget {
  const _DynamicCard({required this.item, required this.onTap});

  final DynamicItemDto item;
  final VoidCallback onTap;

  bool get _playable {
    final bvid = item.bvid;
    final aid = i64(item.aid);
    return bvid.isNotEmpty || aid > 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final text = item.text.trim();
    final title = item.title.trim();
    final cover = item.cover;
    final duration = formatDurationMs(i64(item.durationMs));

    return Material(
      color: colors.elevated.withValues(alpha: 0.55),
      borderRadius: AppShapes.borderMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _playable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.borderSubtle,
                    backgroundImage: item.authorFace.isNotEmpty
                        ? NetworkImage(item.authorFace)
                        : null,
                    child: item.authorFace.isEmpty
                        ? Icon(AppIcons.user, size: AppIcons.sm, color: colors.fgMuted)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.authorName.isEmpty ? '—' : item.authorName,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatPub(i64(item.pubTsMs), locale),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.fgMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (title.isNotEmpty || cover.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _MajorBlock(
                  title: title,
                  coverUrl: cover,
                  durationLabel: duration,
                  playable: _playable,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Stat(
                    icon: AppIcons.like,
                    label: formatCount(i64(item.likeCount), locale: locale),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _Stat(
                    icon: AppIcons.comment,
                    label: formatCount(i64(item.commentCount), locale: locale),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _Stat(
                    icon: AppIcons.share,
                    label: formatCount(i64(item.repostCount), locale: locale),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPub(int ms, Locale locale) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return locale.languageCode.startsWith('zh') ? '刚刚' : 'Just now';
    if (diff.inHours < 1) {
      return locale.languageCode.startsWith('zh')
          ? '${diff.inMinutes} 分钟前'
          : '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return locale.languageCode.startsWith('zh')
          ? '${diff.inHours} 小时前'
          : '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return locale.languageCode.startsWith('zh')
          ? '${diff.inDays} 天前'
          : '${diff.inDays}d';
    }
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    if (y == now.year) return '$m-$d';
    return '$y-$m-$d';
  }
}

class _MajorBlock extends StatelessWidget {
  const _MajorBlock({
    required this.title,
    required this.coverUrl,
    required this.durationLabel,
    required this.playable,
  });

  final String title;
  final String coverUrl;
  final String durationLabel;
  final bool playable;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas.withValues(alpha: 0.65),
        borderRadius: AppShapes.borderSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          if (coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
              child: SizedBox(
                width: 132,
                height: 74,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: colors.borderSubtle,
                        child: Icon(AppIcons.imageBroken, color: colors.fgMuted),
                      ),
                    ),
                    if (durationLabel.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: AppShapes.borderXs,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: Text(
                              durationLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? (playable ? '…' : '') : title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (playable)
                    Icon(AppIcons.playCircle, size: AppIcons.md, color: colors.fgMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIcons.xs, color: colors.fgMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.fgMuted,
              ),
        ),
      ],
    );
  }
}
