import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../l10n/l10n.dart';

/// Like / coin / favorite / share row under the player (display-first).
///
/// Matches Bilibili watch-page engagement chrome; actions are no-ops until
/// social write APIs land. Icon-only + count per design-system §7.7.
class EngagementBar extends StatelessWidget {
  const EngagementBar({super.key, required this.stat});

  final VideoStatDto stat;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          _Action(
            icon: AppIcons.like,
            label: formatCount(i64(stat.like), locale: locale),
            tooltip: l10n.statLike,
            onTap: () => _soon(context),
          ),
          _Action(
            icon: AppIcons.coin,
            label: formatCount(i64(stat.coin), locale: locale),
            tooltip: l10n.statCoin,
            onTap: () => _soon(context),
          ),
          _Action(
            icon: AppIcons.star,
            label: formatCount(i64(stat.favorite), locale: locale),
            tooltip: l10n.statFavorite,
            onTap: () => _soon(context),
          ),
          _Action(
            icon: AppIcons.share,
            label: formatCount(i64(stat.share), locale: locale),
            tooltip: l10n.statShare,
            onTap: () => _soon(context),
          ),
          const Spacer(),
          Text(
            '${l10n.statReply} ${formatCount(i64(stat.reply), locale: locale)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.fgSecondary,
                ),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.actionComingSoon)),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colors.fgPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.fgPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
