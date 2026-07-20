import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/shapes.dart';
import '../theme/spacing.dart';

/// Compact meta chip (views, likes, …) for content surfaces.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: AppShapes.borderFull,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.fgSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.fgSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
