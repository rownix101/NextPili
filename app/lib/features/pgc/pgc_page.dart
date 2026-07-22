import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/video_card.dart';
import '../../l10n/l10n.dart';

/// PGC rank browse (番剧 / 国创 / …).
class PgcPage extends ConsumerStatefulWidget {
  const PgcPage({super.key});

  @override
  ConsumerState<PgcPage> createState() => _PgcPageState();
}

class _PgcPageState extends ConsumerState<PgcPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = <(int, String Function(AppLocalizations))>[
    (1, _tAnime),
    (4, _tGuochuang),
    (2, _tMovie),
    (5, _tTv),
    (3, _tDoc),
    (7, _tVariety),
  ];

  static String _tAnime(AppLocalizations l) => l.pgcTabAnime;
  static String _tGuochuang(AppLocalizations l) => l.pgcTabGuochuang;
  static String _tMovie(AppLocalizations l) => l.pgcTabMovie;
  static String _tTv(AppLocalizations l) => l.pgcTabTv;
  static String _tDoc(AppLocalizations l) => l.pgcTabDoc;
  static String _tVariety(AppLocalizations l) => l.pgcTabVariety;

  late final TabController _tabsCtrl;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.pgcTitle,
        showBack: Navigator.canPop(context),
        bottom: TabBar(
          controller: _tabsCtrl,
          isScrollable: true,
          tabs: [for (final t in _tabs) Tab(text: t.$2(l10n))],
        ),
      ),
      body: TabBarView(
        controller: _tabsCtrl,
        children: [
          for (final t in _tabs) _PgcRankTab(seasonType: t.$1),
        ],
      ),
    );
  }
}

class _PgcRankTab extends StatefulWidget {
  const _PgcRankTab({required this.seasonType});

  final int seasonType;

  @override
  State<_PgcRankTab> createState() => _PgcRankTabState();
}

class _PgcRankTabState extends State<_PgcRankTab> {
  final _items = <PgcRankItemDto>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await CoreApi.instance.pgcRank(
        seasonType: widget.seasonType,
        day: 3,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading && _items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cross = _cross(constraints.maxWidth);
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: AppSpacing.md - 4,
              crossAxisSpacing: AppSpacing.md - 4,
              childAspectRatio: 16 / 13,
            ),
            itemCount: cross * 2,
            itemBuilder: (_, _) => const VideoCardSkeleton(),
          );
        },
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(message: _error!, onRetry: _reload);
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cross = _cross(constraints.maxWidth);
          return CustomScrollView(
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
                    (context, index) {
                      final it = _items[index];
                      final sid = i64(it.seasonId);
                      final badge = it.badge.isNotEmpty
                          ? it.badge
                          : (it.rating.isNotEmpty ? it.rating : null);
                      return VideoCard(
                        title: it.title,
                        coverUrl: it.cover,
                        ownerName: it.indexShow.isNotEmpty
                            ? it.indexShow
                            : l10n.pgcTitle,
                        durationLabel: '',
                        qualityBadge: badge,
                        onTap: () {
                          if (sid <= 0) return;
                          context.push('/pgc/ss/$sid');
                        },
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
              if (!_loading && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: l10n.pgcEmpty,
                    icon: AppIcons.movie,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _cross(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 520) return 2;
    return 1;
  }
}
