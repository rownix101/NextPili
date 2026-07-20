import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/shapes.dart';
import '../theme/spacing.dart';

enum NpButtonVariant { primary, secondary, text, danger }

/// Content-area button (opaque). Chrome may use GlassButton instead.
class NpButton extends StatelessWidget {
  const NpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = NpButtonVariant.primary,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NpButtonVariant variant;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == NpButtonVariant.primary ||
                      variant == NpButtonVariant.danger
                  ? colors.onAccent
                  : colors.accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      NpButtonVariant.primary => FilledButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      NpButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      NpButtonVariant.text => TextButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      NpButtonVariant.danger => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onAccent,
          ),
          child: child,
        ),
    };

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Content-area icon button with ≥40px hit target.
class NpIconButton extends StatelessWidget {
  const NpIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final btn = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: size, color: color ?? colors.fgPrimary),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.borderSm),
      ),
    );
    return btn;
  }
}
