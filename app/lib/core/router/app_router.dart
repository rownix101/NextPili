import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/home/home_page.dart';
import '../../features/player/player_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/user/user_page.dart';
import '../../features/video/video_detail_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchPage(),
            ),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UserPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
          GoRoute(
            path: '/auth',
            name: 'auth',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AuthPage(),
            ),
          ),
          GoRoute(
            path: '/video/:id',
            name: 'video',
            pageBuilder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
              final cid = int.tryParse(state.uri.queryParameters['cid'] ?? '') ?? 0;
              return NoTransitionPage(
                child: VideoDetailPage(videoId: id, initialCid: cid),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/play/:id',
        name: 'play',
        builder: (context, state) {
          final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
          final q = state.uri.queryParameters;
          final cid = int.tryParse(q['cid'] ?? '') ?? 0;
          final aid = int.tryParse(q['aid'] ?? '') ?? 0;
          final bvid = q['bvid'] ?? '';
          final title = q['title'] ?? '';
          final qn = int.tryParse(q['qn'] ?? '') ?? 0;
          return PlayerPage(
            videoId: id,
            cid: cid,
            aid: aid,
            bvid: bvid,
            title: title,
            qn: qn,
          );
        },
      ),
    ],
  );
}
