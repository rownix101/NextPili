import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'engagement_bar.dart';

/// Paginated main-floor comments for a video (`aid`).
///
/// Sort control is token text segments (content area, not glass chrome) —
/// design-system §8.3 / interaction §5.3.
class ReplySection extends ConsumerStatefulWidget {
  const ReplySection({super.key, required this.aid});

  final int aid;

  @override
  ConsumerState<ReplySection> createState() => _ReplySectionState();
}

class _ReplySectionState extends ConsumerState<ReplySection> {
  final List<ReplyDto> _items = [];
  final TextEditingController _composer = TextEditingController();
  String _nextOffset = '';
  bool _isEnd = false;
  int _allCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;
  int _mode = 3; // heat

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReplySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aid != widget.aid) {
      _composer.clear();
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
    Haptics.selection();
    setState(() => _mode = mode);
    _reload();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final l10n = context.l10n;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.replyEmptyMessage)),
      );
      return;
    }
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final posted = await CoreApi.instance.replyAdd(
        oid: widget.aid,
        message: text,
      );
      if (!mounted) return;
      Haptics.success();
      setState(() {
        _items.insert(0, posted);
        _allCount += 1;
        _composer.clear();
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.replySent)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
    }
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
            Expanded(
              child: Text(
                _allCount > 0
                    ? l10n.replyTitleWithCount(_allCount)
                    : l10n.replyTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            _SortSegment(
              mode: _mode,
              onChanged: _setMode,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_sending) _send();
                },
                decoration: InputDecoration(
                  hintText: l10n.replyHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            NpButton(
              label: l10n.replySend,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
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
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accent,
                        ),
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

/// Text segmented control for comment sort (content token, not M3 SegmentedButton).
class _SortSegment extends StatelessWidget {
  const _SortSegment({
    required this.mode,
    required this.onChanged,
  });

  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: AppShapes.borderSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortChip(
            label: l10n.replySortHeat,
            selected: mode == 3,
            onTap: () => onChanged(3),
          ),
          _SortChip(
            label: l10n.replySortTime,
            selected: mode == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Material(
      color: selected ? colors.elevated : Colors.transparent,
      borderRadius: AppShapes.borderSm,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: AppShapes.borderSm,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs,
              ),
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? colors.accent : colors.fgSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
                ? Icon(AppIcons.user, size: AppIcons.xs, color: colors.fgSecondary)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${i64(reply.like)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.fgMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // type.bodyLg ≈ bodyLarge for comment body — design-system §5.2.
                SelectableText(
                  reply.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.fgPrimary,
                    height: 1.5,
                  ),
                ),
                if (reply.childrenCount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
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
