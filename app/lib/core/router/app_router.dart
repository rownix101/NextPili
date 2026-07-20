import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';
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
              return NoTransitionPage(
                child: VideoDetailPage(videoId: id),
              );
            },
          ),
        ],
      ),
    ],
  );
}
