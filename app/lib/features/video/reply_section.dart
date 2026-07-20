import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';

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
        _error = errorMessage(e, context.l10n);
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
        SnackBar(content: Text(errorMessage(e, context.l10n))),
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
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _allCount > 0
                  ? l10n.replyTitleWithCount(_allCount)
                  : l10n.replyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 3, label: Text(l10n.replySortHeat)),
                ButtonSegment(value: 2, label: Text(l10n.replySortTime)),
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
            message: l10n.replyEmpty,
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
                      label: l10n.loadMore,
                      variant: NpButtonVariant.text,
                      onPressed: _loadMore,
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.noMore,
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
    final l10n = context.l10n;
    final uname = reply.uname.isEmpty ? l10n.user : reply.uname;

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
                    l10n.replyChildrenCount(reply.childrenCount),
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
