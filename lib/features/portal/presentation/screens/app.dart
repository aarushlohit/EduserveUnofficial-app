import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:eduserveapp/core/theme/app_theme.dart';
import 'package:eduserveapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:eduserveapp/features/auth/presentation/screens/login_screen.dart';
import 'package:eduserveapp/features/auth/presentation/screens/splash_screen.dart';
import 'package:eduserveapp/features/portal/presentation/providers/portal_provider.dart';
import 'package:eduserveapp/features/portal/presentation/screens/home_screen.dart';
import 'package:eduserveapp/features/portal/presentation/screens/settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Router
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final status = auth.status;

      // Stay on splash while checking.
      if (status == AuthStatus.initial ||
          status == AuthStatus.checkingSession) {
        return location == '/splash' ? null : '/splash';
      }

      // Redirect logged-in users away from splash / login.
      if (status == AuthStatus.authenticated) {
        if (location == '/splash' || location == '/login') {
          return '/home';
        }
        return null;
      }

      // Unauthenticated / error → login.
      if (location != '/login') return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EduServeApp root widget
// ─────────────────────────────────────────────────────────────────────────────

class EduServeApp extends StatefulWidget {
  const EduServeApp({super.key});

  @override
  State<EduServeApp> createState() => _EduServeAppState();
}

class _EduServeAppState extends State<EduServeApp> {
  // GoRouter must be created ONCE. refreshListenable inside the router
  // handles redirect recalculation whenever AuthProvider notifies — there is
  // no need (and it is harmful) to recreate the router on every build.
  late final GoRouter _router;
  bool _routerBuilt = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routerBuilt) {
      _router = _buildRouter(context.read<AuthProvider>());
      _routerBuilt = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();

    return MaterialApp.router(
      title: 'EduServe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: portal.themeMode,
      routerConfig: _router,
    );
  }
}
