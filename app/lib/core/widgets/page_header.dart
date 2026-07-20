import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'np_button.dart';

/// Content-page top bar (opaque). Shell chrome may use glass instead.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppBar(
      title: Text(title),
      backgroundColor: colors.canvas,
      leading: leading ??
          (showBack
              ? NpIconButton(
                  icon: AppIcons.arrowLeft,
                  tooltip: '返回',
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                )
              : null),
      actions: [
        ...actions,
        const SizedBox(width: AppSpacing.sm),
      ],
      bottom: bottom,
    );
  }
}
