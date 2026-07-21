import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';
import 'fav_tab.dart';
import 'history_tab.dart';
import 'toview_tab.dart';

/// Personal library: history · watch later · favorites.
class UserPage extends ConsumerStatefulWidget {
  const UserPage({super.key});

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.navLibrary,
        actions: [
          NpIconButton(
            tooltip: l10n.account,
            icon: AppIcons.user,
            onPressed: () => context.push('/auth'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.libraryTabHistory),
            Tab(text: l10n.libraryTabToview),
            Tab(text: l10n.libraryTabFav),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          HistoryTab(),
          ToViewTab(),
          FavTab(),
        ],
      ),
    );
  }
}
