import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/shapes.dart';

/// Opaque elevated surface for content (not glass) — design-system §2 / §8.2.
class ContentSurface extends StatelessWidget {
  const ContentSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = borderRadius ?? AppShapes.borderMd;

    final body = Material(
      color: colors.elevated,
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );

    if (onTap == null) return body;

    return Material(
      color: colors.elevated,
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: colors.fgPrimary.withValues(alpha: 0.04),
        focusColor: colors.accent.withValues(alpha: 0.12),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
