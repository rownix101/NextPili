import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/shapes.dart';
import '../theme/spacing.dart';

/// Centered circular progress using accent token.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: colors.accent,
        ),
      ),
    );
  }
}

/// Simple skeleton block for first-paint placeholders.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: borderRadius ?? AppShapes.borderSm,
      ),
    );
  }
}

/// Feed-style skeleton grid cell.
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: AppShapes.borderMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 7, child: ColoredBox(color: colors.sunken)),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: double.infinity),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonBox(height: 14, width: 120),
                  const Spacer(),
                  const SkeletonBox(height: 12, width: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
