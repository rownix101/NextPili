import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';

/// Paginated main-floor comments for a video (`aid`).
class ReplySection extends ConsumerStatefulWidget {
  const ReplySection({super.key, required this.aid});

  final int aid;

  @override
  ConsumerState<ReplySection> createState() => _ReplySectionState();
}

class _ReplySectionState extends ConsumerState<ReplySection> {
  final List<ReplyDto> _items = [];
  String _nextOffset = '';
  bool _isEnd = false;
  int _allCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _mode = 3; // heat

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ReplySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aid != widget.aid) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextOffset = '';
      _isEnd = false;
      _allCount = 0;
    });
    try {
      final page = await CoreApi.instance.replyList(
        oid: widget.aid,
        mode: _mode,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.replies);
        _nextOffset = page.nextOffset;
        _isEnd = page.isEnd;
        _allCount = i64(page.allCount);
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
    if (_loadingMore || _isEnd || _nextOffset.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CoreApi.instance.replyList(
        oid: widget.aid,
        mode: _mode,
        nextOffset: _nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.replies);
        _nextOffset = page.nextOffset;
        _isEnd = page.isEnd;
        if (i64(page.allCount) > 0) {
          _allCount = i64(page.allCount);
        }
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

  void _setMode(int mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _allCount > 0 ? '评论 ($_allCount)' : '评论',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('热度')),
                ButtonSegment(value: 2, label: Text('时间')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _setMode(s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppLoading(),
          )
        else if (_error != null)
          EmptyState.error(message: _error!, onRetry: _reload)
        else if (_items.isEmpty)
          EmptyState(
            message: '还没有评论',
            icon: AppIcons.comment,
          )
        else ...[
          for (final r in _items) _ReplyTile(reply: r),
          const SizedBox(height: AppSpacing.sm),
          if (!_isEnd)
            Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : NpButton(
                      label: '加载更多',
                      variant: NpButtonVariant.text,
                      onPressed: _loadMore,
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '没有更多了',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.fgMuted,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final ReplyDto reply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final uname = reply.uname.isEmpty ? '用户' : reply.uname;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.sunken,
            backgroundImage:
                reply.avatar.isNotEmpty ? NetworkImage(reply.avatar) : null,
            child: reply.avatar.isEmpty
                ? Icon(AppIcons.user, size: 16, color: colors.fgSecondary)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        uname,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i64(reply.like) > 0) ...[
                      Icon(AppIcons.like, size: 14, color: colors.fgMuted),
                      const SizedBox(width: 2),
                      Text(
                        '${i64(reply.like)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.fgMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  reply.content,
                  style: theme.textTheme.bodyMedium,
                ),
                if (reply.childrenCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${reply.childrenCount} 条回复',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.fgSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
