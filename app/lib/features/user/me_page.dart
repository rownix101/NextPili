import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';

/// Mobile hub: account, live, PGC, settings (interaction §1.1).
///
/// Not a primary feed — secondary destinations demoted from the 4-tab bar.
class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget tile({
      required IconData icon,
      required String title,
      required String? subtitle,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: colors.fgSecondary, size: AppIcons.md),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(color: colors.fgPrimary),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.fgSecondary),
              ),
        trailing: Icon(
          AppIcons.chevronRight,
          color: colors.fgMuted,
          size: AppIcons.sm,
        ),
        onTap: onTap,
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(title: l10n.navMe),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          tile(
            icon: AppIcons.user,
            title: l10n.account,
            subtitle: l10n.settingsAccountSubtitle,
            onTap: () => context.push('/auth'),
          ),
          const Divider(height: 1),
          tile(
            icon: AppIcons.live,
            title: l10n.navLive,
            subtitle: null,
            onTap: () => context.push('/live'),
          ),
          tile(
            icon: AppIcons.movie,
            title: l10n.navPgc,
            subtitle: null,
            onTap: () => context.push('/pgc'),
          ),
          const Divider(height: 1),
          tile(
            icon: AppIcons.settings,
            title: l10n.navSettings,
            subtitle: null,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}
