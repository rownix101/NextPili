import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'np_button.dart';

/// Empty / error state — design-system §8.8.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = AppIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  factory EmptyState.error({
    Key? key,
    required String message,
    VoidCallback? onRetry,
    String retryLabel = '重试',
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return EmptyState(
      key: key,
      message: message,
      icon: AppIcons.cloudOff,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppIcons.xl + 8, color: colors.fgMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.fgSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                NpButton(label: actionLabel!, onPressed: onAction),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                NpButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                  variant: NpButtonVariant.text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
