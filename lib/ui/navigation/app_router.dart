import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tooling/driver_test_mode.dart';
import '../features/home/home_screen.dart';
import '../features/layout/main_layout.dart';
import '../features/login/login_screen.dart';
import '../features/media_library/media_library_screen.dart';
import '../features/folder/folder_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/movie_detail/movie_detail_screen.dart';
import '../features/tv_detail/tv_detail_screen.dart';
import '../features/tv_detail/tv_season_detail_screen.dart';
import '../features/person_detail/person_detail_screen.dart';
import '../features/player/player_screen.dart';
import '../features/player/live_player_screen.dart';
import '../../core/utils/log/app_talker.dart';
import '../../providers/providers.dart';

// Driver-only: opens a specific route on launch (e.g. /player/<guid>) so
// automated verification can bypass hover/tap navigation on static screens.
// Ignored in production builds.
const String _driverInitialRoute =
    String.fromEnvironment('DRIVER_INITIAL_ROUTE');

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(preferencesManagerProvider);
  ref.watch(authRefreshProvider);

  return GoRouter(
    initialLocation: (kDriverTestMode && _driverInitialRoute.isNotEmpty)
        ? _driverInitialRoute
        : '/login',
    redirect: (context, state) {
      final token = prefs.getToken();
      final baseUrl = prefs.getBaseUrl();
      final isLoggedIn = token != null && baseUrl != null;
      final isOnLogin = state.matchedLocation == '/login';
      AppTalker.info(
        'Router',
        'location="${state.matchedLocation}" token=${token != null} tokenLength=${token?.length ?? 0} baseUrl=${baseUrl != null} isLoggedIn=$isLoggedIn',
      );

      if (!isLoggedIn) {
        return isOnLogin ? null : '/login';
      }

      return isOnLogin ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Player route - outside ShellRoute for fullscreen
      GoRoute(
        path: '/player/:guid',
        builder: (context, state) => PlayerScreen(
          guid: state.pathParameters['guid'] ?? '',
          mediaGuid: state.uri.queryParameters['media_guid'],
          audioGuid: state.uri.queryParameters['audio_guid'],
          subtitleGuid: state.uri.queryParameters['subtitle_guid'],
        ),
      ),
      // IPTV live-channel player route.
      GoRoute(
        path: '/live/:guid',
        builder: (context, state) => LivePlayerScreen(
          guid: state.pathParameters['guid'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(state: state, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/library/:id',
            builder: (context, state) =>
                MediaLibraryScreen(id: state.pathParameters['id']),
          ),
          // 文件夹视图（Web /v/folder/:guid）：目录项（fv_*）钻取浏览。
          GoRoute(
            path: '/folder/:guid',
            builder: (context, state) =>
                FolderScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/category/:type',
            builder: (context, state) =>
                MediaLibraryScreen(categoryType: state.pathParameters['type']),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/movie/:guid',
            builder: (context, state) =>
                MovieDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/tv/:guid',
            builder: (context, state) =>
                TvDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/tv/season/:guid',
            builder: (context, state) =>
                TvSeasonDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          // 集详情页（Web /v/tv/episode/:guid）：从选集海报空白区进入，
          // 复用电影详情页，由内容自行识别 Episode 类型渲染剧集布局。
          GoRoute(
            path: '/tv/episode/:guid',
            builder: (context, state) =>
                MovieDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/person/:guid',
            builder: (context, state) =>
                PersonDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
        ],
      ),
    ],
  );
});
