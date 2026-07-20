import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'engagement_bar.dart';

/// UP card on the watch-page right rail (avatar, name, follow).
class OwnerCard extends ConsumerStatefulWidget {
  const OwnerCard({
    super.key,
    required this.detail,
  });

  final VideoDetailDto detail;

  @override
  ConsumerState<OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends ConsumerState<OwnerCard> {
  bool _busy = false;
  bool? _followingOverride;

  String get _key =>
      relationKey(i64(widget.detail.aid), widget.detail.bvid);

  Future<bool> _ensureLogin() async {
    if (isLoggedIn()) return true;
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.loginRequiredTitle),
        content: Text(l10n.loginRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.goLogin),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      context.push('/auth');
    }
    return false;
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_busy) return;
    if (!await _ensureLogin()) return;
    final next = !currentlyFollowing;
    setState(() {
      _busy = true;
      _followingOverride = next;
    });
    try {
      await CoreApi.instance.relationFollow(
        mid: i64(widget.detail.ownerMid),
        follow: next,
      );
      ref.invalidate(videoRelationProvider(_key));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next ? context.l10n.followSuccess : context.l10n.unfollowSuccess,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _followingOverride = currentlyFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(e, context.l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final detail = widget.detail;
    final rel = ref.watch(videoRelationProvider(_key)).asData?.value;
    final following = _followingOverride ?? rel?.following ?? false;

    return ContentPad(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.sunken,
            backgroundImage: detail.ownerFace.isNotEmpty
                ? NetworkImage(detail.ownerFace)
                : null,
            child: detail.ownerFace.isEmpty
                ? Icon(AppIcons.user, size: 22, color: colors.fgSecondary)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.ownerName.isEmpty ? l10n.user : detail.ownerName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detail.bvid.isNotEmpty
                      ? detail.bvid
                      : 'av${i64(detail.aid)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.fgMuted,
                  ),
                ),
              ],
            ),
          ),
          NpButton(
            label: following ? l10n.following : l10n.follow,
            icon: following ? AppIcons.check : AppIcons.plus,
            variant: following
                ? NpButtonVariant.secondary
                : NpButtonVariant.primary,
            onPressed: _busy
                ? null
                : () => _toggleFollow(following),
          ),
        ],
      ),
    );
  }
}

/// Thin padding shell for rail cards.
class ContentPad extends StatelessWidget {
  const ContentPad({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: AppShapes.borderMd,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: child,
    );
  }
}
