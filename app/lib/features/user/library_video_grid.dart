import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/widgets/loading.dart';

/// Shared responsive grid used by library history / toview / fav tabs.
class LibraryVideoGrid extends StatelessWidget {
  const LibraryVideoGrid({
    super.key,
    required this.scroll,
    required this.itemCount,
    required this.builder,
    this.loadingMore = false,
  });

  final ScrollController scroll;
  final int itemCount;
  final bool loadingMore;
  final Widget Function(BuildContext context, int index) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = _crossAxisCount(constraints.maxWidth);
        return CustomScrollView(
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: AppSpacing.md - 4,
                  crossAxisSpacing: AppSpacing.md - 4,
                  childAspectRatio: 16 / 13,
                ),
                delegate: SliverChildBuilderDelegate(
                  builder,
                  childCount: itemCount,
                ),
              ),
            ),
            if (loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: AppLoading(size: 24),
                ),
              ),
          ],
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 520) return 2;
    return 1;
  }
}
