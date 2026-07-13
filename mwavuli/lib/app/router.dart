import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/community/community_screen.dart';
import '../features/community/user_profile_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/log/log_flow.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/welcome/welcome_screen.dart';
import '../features/map/tree_detail_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Central router. Four bottom-nav branches (explore/map/community/profile)
/// live under a [StatefulShellRoute] so their state is preserved when
/// switching tabs. Welcome, the Log flow, and Tree detail are full-screen
/// routes pushed above the shell.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/log',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LogFlow(),
      ),
      GoRoute(
        path: '/tree/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            TreeDetailScreen(treeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/user/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            UserProfileScreen(userId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/community',
                builder: (_, __) => const CommunityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
