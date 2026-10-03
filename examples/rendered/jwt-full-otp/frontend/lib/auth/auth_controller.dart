import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_api_client/export.dart';

import '../api/rest_client_provider.dart';

part 'auth_controller.g.dart';

/// A signup awaiting OTP verification: the email plus the short-lived token
/// returned by /auth/signup, submitted together with the emailed code.
typedef PendingVerification = ({String email, String token});

/// Holds the pending verification between the signup and OTP screens. Null when
/// nothing is awaiting verification.
@Riverpod(keepAlive: true)
class PendingVerificationController extends _$PendingVerificationController {
  @override
  PendingVerification? build() => null;

  PendingVerification? get value => state;
  set value(PendingVerification next) => state = next;
  void clear() => state = null;
}

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
    } on Exception catch (_) {
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
      // Signup does not start a session. The backend emails a one-time code and
      // returns a verification token; stash both and route to the OTP screen.
      final resp = await ref.read(authClientProvider).signup(
            body: SignupRequest(email: email, password: password, name: name),
          );
      ref.read(pendingVerificationControllerProvider.notifier).value =
          (email: email, token: resp.verificationToken);
      return null; // still signed out until the OTP is verified
    });
  }

  /// Submits the emailed OTP for the pending signup. On success the account is
  /// verified, a session is persisted, and the user is signed in.
  Future<void> verifyOtp(String code) async {
    final pending = ref.read(pendingVerificationControllerProvider);
    if (pending == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authClientProvider).verifyEmail(
            body: VerifyRequest(verificationToken: pending.token, code: code),
          );
      await _persist(session);
      ref.read(pendingVerificationControllerProvider.notifier).clear();
      return session.user;
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
      } on Exception catch (_) {
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
