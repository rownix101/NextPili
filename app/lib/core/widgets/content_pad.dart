import 'package:flutter/material.dart';

import '../theme/spacing.dart';

/// Standard horizontal/vertical content inset.
class ContentPad extends StatelessWidget {
  const ContentPad({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}
