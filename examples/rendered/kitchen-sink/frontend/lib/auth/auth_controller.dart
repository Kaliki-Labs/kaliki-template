import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_api_client/export.dart';

import '../api/rest_client_provider.dart';

part 'auth_controller.g.dart';

/// Holds the authenticated [User] (or null when signed out). On startup it
/// tries to load the current user from a persisted token.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<User?> build() async {
    final token = await ref.read(tokenStorageProvider).getAccessToken();
    if (token == null) return null;
    try {
      return await ref.read(authClientProvider).getCurrentUser();
    } on Object catch (_) {
      await ref.read(tokenStorageProvider).clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authClientProvider).login(
            body: LoginRequest(email: email, password: password),
          );
      await _persist(session);
      return session.user;
    });
  }

  Future<void> signup(String email, String password, String? name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Signup does not start a session. The backend emails a verification
      // link; the user clicks it, then logs in.
      await ref.read(authClientProvider).signup(
            body: SignupRequest(email: email, password: password, name: name),
          );
      return null; // still signed out until the email is verified
    });
  }

  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    final refresh = await storage.getRefreshToken();
    if (refresh != null) {
      try {
        await ref.read(authClientProvider).logout(
              body: RefreshRequest(refreshToken: refresh),
            );
      } on Object catch (_) {
        // Best effort; clear locally regardless.
      }
    }
    await storage.clear();
    state = const AsyncData(null);
  }

  Future<void> _persist(AuthResponse session) async {
    await ref
        .read(tokenStorageProvider)
        .setTokens(session.token, session.refreshToken);
  }
}
