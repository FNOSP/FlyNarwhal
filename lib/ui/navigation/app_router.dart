import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/home_screen.dart';
import '../features/layout/main_layout.dart';
import '../features/login/login_screen.dart';
import '../features/media_library/media_library_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/movie_detail/movie_detail_screen.dart';
import '../features/tv_detail/tv_detail_screen.dart';
import '../features/tv_detail/tv_season_detail_screen.dart';
import '../features/person_detail/person_detail_screen.dart';
import '../features/player/player_screen.dart';
import '../../core/utils/log/app_talker.dart';
import '../../providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(preferencesManagerProvider);
  ref.watch(authRefreshProvider);
  
  return GoRouter(
    initialLocation: '/login',
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
            builder: (context, state) => MediaLibraryScreen(id: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/category/:type',
            builder: (context, state) => MediaLibraryScreen(categoryType: state.pathParameters['type']),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/movie/:guid',
            builder: (context, state) => MovieDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/tv/:guid',
            builder: (context, state) => TvDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/tv/season/:guid',
            builder: (context, state) => TvSeasonDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
          GoRoute(
            path: '/person/:guid',
            builder: (context, state) => PersonDetailScreen(guid: state.pathParameters['guid'] ?? ''),
          ),
        ],
      ),
    ],
  );
});
