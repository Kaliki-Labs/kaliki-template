import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_controller.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/signup_screen.dart';
import 'app_shell.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  // Bridge the auth state into a Listenable so GoRouter re-evaluates redirects.
  final refresh = ValueNotifier<Object?>(null);
  ref
    ..onDispose(refresh.dispose)
    ..listen(
      authControllerProvider,
      (_, next) => refresh.value = next,
      fireImmediately: true,
    )
    ..listen(
      pendingVerificationControllerProvider,
      (_, next) => refresh.value = next,
      fireImmediately: true,
    );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null; // wait for the initial load
      final loggedIn = auth.value != null;
      final awaitingOtp =
          ref.read(pendingVerificationControllerProvider) != null;
      final onOtpScreen = state.matchedLocation == '/verify';
      if (!loggedIn && awaitingOtp) return onOtpScreen ? null : '/verify';
      if (onOtpScreen) return loggedIn ? '/' : '/login';
      final onAuthScreen = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!loggedIn && !onAuthScreen) return '/login';
      if (loggedIn && onAuthScreen) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const OtpScreen()),
      // Authenticated routes share the AppShell (app bar + sign-out). Add new
      // authed screens as GoRoute entries here.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        ],
      ),
    ],
  );
}
