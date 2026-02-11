import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home/home_screen.dart';
import '../screens/layout/main_layout.dart';
import '../screens/login/login_screen.dart';
import '../screens/media_library/media_library_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/movie_detail/movie_detail_screen.dart';
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
      debugPrint('[Router] location="${state.matchedLocation}" token=${token != null} tokenLength=${token?.length ?? 0} baseUrl=${baseUrl != null} isLoggedIn=$isLoggedIn');

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
        ],
      ),
    ],
  );
});
