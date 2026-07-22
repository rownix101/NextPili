import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'durations.dart';
import 'easings.dart';

/// Whether the platform / user prefers reduced motion.
bool appReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Duration that collapses under reduce-motion.
///
/// Default [reduced] is [AppDuration.none] (true zero). Pass a short residual
/// (e.g. [AppDuration.short2]) only when a ≤100ms fade still aids comprehension
/// (player chrome — motion.md §6).
Duration appMotionDuration(
  BuildContext context,
  Duration normal, {
  Duration reduced = AppDuration.none,
}) {
  return appReduceMotion(context) ? reduced : normal;
}

/// Page / switcher transitions — docs/ux/motion.md §4–§5.
///
/// Prefer these factories over ad-hoc [PageRouteBuilder] / magic durations.
abstract final class AppTransitions {
  /// Same-level shell tabs (recommend ↔ live). Fade through; short.
  static CustomTransitionPage<T> fadeThrough<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration? duration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
      transitionDuration: duration ?? AppDuration.medium1,
      reverseTransitionDuration: duration ?? AppDuration.medium1,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (appReduceMotion(context)) {
          return _fadeOnly(animation, child);
        }
        return _fadeThrough(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }

  /// Hierarchical push (list → detail). Short shared-axis X + fade.
  ///
  /// [offsetFraction] is a fraction of child width (desktop ~0.02 ≈ 8–16px).
  static CustomTransitionPage<T> sharedAxisX<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    bool reverse = false,
    double offsetFraction = 0.02,
    Duration? duration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
      transitionDuration: duration ?? AppDuration.medium2,
      reverseTransitionDuration: duration ?? AppDuration.medium2,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (appReduceMotion(context)) {
          return _fadeOnly(animation, child);
        }
        final dir = reverse ? -1.0 : 1.0;
        final enter =
            Tween<Offset>(
              begin: Offset(dir * offsetFraction, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: AppEasing.standardDecelerate,
                reverseCurve: AppEasing.standardAccelerate,
              ),
            );
        final exit =
            Tween<Offset>(
              begin: Offset.zero,
              end: Offset(-dir * offsetFraction, 0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: AppEasing.standardAccelerate,
              ),
            );
        return SlideTransition(
          position: exit,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.84).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: AppEasing.standard,
              ),
            ),
            child: SlideTransition(
              position: enter,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: AppEasing.standardDecelerate,
                  reverseCurve: AppEasing.standardAccelerate,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// List → detail with cover [Hero] (container transform).
  ///
  /// Page itself only fades; the cover morph is the [Hero] flight.
  /// Prefer pairing with [AppHeroTags.videoCover] on both ends.
  static CustomTransitionPage<T> containerTransform<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration? duration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
      transitionDuration: duration ?? AppDuration.medium2,
      reverseTransitionDuration: duration ?? AppDuration.medium1,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (appReduceMotion(context)) {
          return _fadeOnly(animation, child);
        }
        final inFade = CurvedAnimation(
          parent: animation,
          curve: AppEasing.standardDecelerate,
          reverseCurve: AppEasing.standardAccelerate,
        );
        final outFade = Tween<double>(begin: 1, end: 0.92).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: AppEasing.standardAccelerate,
          ),
        );
        return FadeTransition(
          opacity: outFade,
          child: FadeTransition(opacity: inFade, child: child),
        );
      },
    );
  }

  /// Fullscreen play / live room enter-exit.
  static CustomTransitionPage<T> fade<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration? duration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
      transitionDuration: duration ?? AppDuration.medium1,
      reverseTransitionDuration: duration ?? AppDuration.medium1,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _fadeOnly(animation, child);
      },
    );
  }

  /// Modal dialog scale 0.9→1 + fade (for custom routes; GlassDialog may use own).
  static CustomTransitionPage<T> modalScale<T>({
    required LocalKey key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration? duration,
    bool opaque = false,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x80000000),
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
      opaque: opaque,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      transitionDuration: duration ?? AppDuration.medium2,
      reverseTransitionDuration: duration ?? AppDuration.short3,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (appReduceMotion(context)) {
          return _fadeOnly(animation, child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppEasing.standardDecelerate,
          reverseCurve: AppEasing.standardAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// [AnimatedSwitcher] layout for same-level content (tabs).
  static Widget fadeThroughSwitcher({
    required Widget child,
    Duration duration = AppDuration.medium1,
    bool reduceMotion = false,
  }) {
    final d = reduceMotion ? AppDuration.instant : duration;
    return AnimatedSwitcher(
      duration: d,
      switchInCurve: AppEasing.standardDecelerate,
      switchOutCurve: AppEasing.standardAccelerate,
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        final scale = Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppEasing.standardDecelerate,
          ),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        );
      },
      child: child,
    );
  }
}

Widget _fadeOnly(Animation<double> animation, Widget child) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: AppEasing.standard),
    child: child,
  );
}

/// Outgoing accelerates away; incoming decelerates in (optional micro-scale).
Widget _fadeThrough({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final inFade = CurvedAnimation(
    parent: animation,
    curve: AppEasing.standardDecelerate,
    reverseCurve: AppEasing.standardAccelerate,
  );
  final inScale = Tween<double>(begin: 0.96, end: 1).animate(
    CurvedAnimation(
      parent: animation,
      curve: AppEasing.standardDecelerate,
      reverseCurve: AppEasing.standardAccelerate,
    ),
  );
  final outFade = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppEasing.standardAccelerate,
    ),
  );

  return FadeTransition(
    opacity: outFade,
    child: FadeTransition(
      opacity: inFade,
      child: ScaleTransition(scale: inScale, child: child),
    ),
  );
}
