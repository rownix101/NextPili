import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/dynamics/dynamics_page.dart';
import '../../features/home/home_page.dart';
import '../../features/live/live_page.dart';
import '../../features/live/live_room_page.dart';
import '../../features/pgc/pgc_page.dart';
import '../../features/pgc/pgc_season_page.dart';
import '../../features/player/player_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/user/user_page.dart';
import '../../features/video/video_detail_page.dart';
import '../motion/app_motion.dart';

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
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: '/live',
            name: 'live',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const LivePage(),
            ),
          ),
          GoRoute(
            path: '/pgc',
            name: 'pgc',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const PgcPage(),
            ),
          ),
          GoRoute(
            path: '/pgc/ss/:seasonId',
            name: 'pgcSeason',
            pageBuilder: (context, state) {
              final seasonId =
                  int.tryParse(state.pathParameters['seasonId'] ?? '') ?? 0;
              final epId =
                  int.tryParse(state.uri.queryParameters['ep'] ?? '') ?? 0;
              return AppTransitions.sharedAxisX(
                key: state.pageKey,
                name: state.name,
                child: PgcSeasonPage(
                  seasonId: seasonId,
                  initialEpId: epId,
                ),
              );
            },
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const SearchPage(),
            ),
          ),
          GoRoute(
            path: '/dynamics',
            name: 'dynamics',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const DynamicsPage(),
            ),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const UserPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => AppTransitions.fadeThrough(
              key: state.pageKey,
              name: state.name,
              child: const SettingsPage(),
            ),
          ),
          GoRoute(
            path: '/auth',
            name: 'auth',
            pageBuilder: (context, state) => AppTransitions.sharedAxisX(
              key: state.pageKey,
              name: state.name,
              child: const AuthPage(),
            ),
          ),
          GoRoute(
            path: '/video/:id',
            name: 'video',
            pageBuilder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
              final cid =
                  int.tryParse(state.uri.queryParameters['cid'] ?? '') ?? 0;
              // motion §4.4 / §5.1 — container transform + cover Hero.
              return AppTransitions.containerTransform(
                key: state.pageKey,
                name: state.name,
                child: VideoDetailPage(videoId: id, initialCid: cid),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/live/:roomId',
        name: 'liveRoom',
        pageBuilder: (context, state) {
          final roomId =
              int.tryParse(state.pathParameters['roomId'] ?? '') ?? 0;
          final title = state.uri.queryParameters['title'] ?? '';
          return AppTransitions.fade(
            key: state.pageKey,
            name: state.name,
            duration: AppDuration.medium2,
            child: LiveRoomPage(roomId: roomId, title: title),
          );
        },
      ),
      GoRoute(
        path: '/play/:id',
        name: 'play',
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
          final q = state.uri.queryParameters;
          final cid = int.tryParse(q['cid'] ?? '') ?? 0;
          final aid = int.tryParse(q['aid'] ?? '') ?? 0;
          final bvid = q['bvid'] ?? '';
          final title = q['title'] ?? '';
          final qn = int.tryParse(q['qn'] ?? '') ?? 0;
          return AppTransitions.fade(
            key: state.pageKey,
            name: state.name,
            duration: AppDuration.medium2,
            child: PlayerPage(
              videoId: id,
              cid: cid,
              aid: aid,
              bvid: bvid,
              title: title,
              qn: qn,
            ),
          );
        },
      ),
    ],
  );
}
