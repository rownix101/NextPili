import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';

/// UP card on the watch-page right rail (avatar, name, follow placeholder).
class OwnerCard extends StatelessWidget {
  const OwnerCard({super.key, required this.detail});

  final VideoDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

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
            label: l10n.follow,
            icon: AppIcons.plus,
            variant: NpButtonVariant.secondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.actionComingSoon)),
              );
            },
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
