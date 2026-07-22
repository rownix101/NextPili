import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// SnackBar enter/exit aligned with motion.md §5.3 (bottom slide + fade timing).
///
/// Prefer this over raw [ScaffoldMessenger.showSnackBar] so every toast uses
/// [AppDuration] / reduce-motion, and replaces the previous bar (no queue).
abstract final class AppSnackBar {
  /// Show a text snack bar. Replaces any current one by default.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    SnackBarAction? action,
    Duration? duration,
    bool replace = true,
  }) {
    return showRaw(
      context,
      SnackBar(
        content: Text(message),
        action: action,
        duration:
            duration ??
            (action != null
                ? const Duration(seconds: 4)
                : const Duration(seconds: 3)),
      ),
      replace: replace,
    );
  }

  /// Show a pre-built [SnackBar] with app motion style.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showRaw(
    BuildContext context,
    SnackBar snackBar, {
    bool replace = true,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    if (replace) {
      messenger.hideCurrentSnackBar();
    }
    return messenger.showSnackBar(
      snackBar,
      snackBarAnimationStyle: animationStyleOf(context),
    );
  }

  /// Enter [AppDuration.medium1], exit [AppDuration.short3]; none under reduce-motion.
  static AnimationStyle animationStyleOf(BuildContext context) {
    if (appReduceMotion(context)) {
      return AnimationStyle.noAnimation;
    }
    return const AnimationStyle(
      duration: AppDuration.medium1,
      reverseDuration: AppDuration.short3,
    );
  }
}
