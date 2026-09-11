import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opaque chrome surface for desktop Rail / compact bottom navigation.
///
/// Desktop chrome no longer depends on a native system material or wallpaper
/// sample. It uses the semantic elevated surface token plus an optional edge
/// border; content stays on the canvas layer.
class ChromeSurface extends StatelessWidget {
  const ChromeSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.border,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.elevated,
          border: border,
        ),
        child: content,
      ),
    );
  }
}
