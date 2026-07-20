import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'engagement_bar.dart';

/// UP card on the watch-page right rail (avatar, name, follow).
///
/// Content surface (opaque) — design-system §2 / §8; follow CTA with visible
/// text — §7.7; login gate — interaction §8.
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

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
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
      await Haptics.impactLight();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              next ? context.l10n.followSuccess : context.l10n.unfollowSuccess,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _followingOverride = currentlyFollowing);
      await Haptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e, context.l10n))),
      );
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
    final mid = i64(detail.ownerMid);

    final name = detail.ownerName.isEmpty ? l10n.user : detail.ownerName;
    final openProfile = mid > 0 ? () => context.push('/user/$mid') : null;

    return ContentSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openProfile,
                borderRadius: AppShapes.borderSm,
                hoverColor: colors.fgPrimary.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colors.sunken,
                          backgroundImage: detail.ownerFace.isNotEmpty
                              ? NetworkImage(detail.ownerFace)
                              : null,
                          child: detail.ownerFace.isEmpty
                              ? Icon(
                                  AppIcons.user,
                                  size: AppIcons.sm,
                                  color: colors.fgSecondary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Follow is a CTA — visible text required (design-system §7.7).
          NpButton(
            label: following ? l10n.following : l10n.follow,
            icon: following ? AppIcons.check : AppIcons.plus,
            loading: _busy,
            variant: following
                ? NpButtonVariant.secondary
                : NpButtonVariant.primary,
            onPressed: _busy ? null : () => _toggleFollow(following),
          ),
        ],
      ),
    );
  }
}
