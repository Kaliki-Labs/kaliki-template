import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jwt_full_otp_app/auth/auth_controller.dart';
import 'package:jwt_full_otp_app/screens/otp_screen.dart';
import 'package:shared_api_client/export.dart';

class _ThrottledAuth extends AuthController {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> resendOtp() async {
    final req = RequestOptions(path: '/auth/verify/resend');
    throw DioException(
      requestOptions: req,
      response: Response<void>(
        requestOptions: req,
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['30'],
        }),
      ),
    );
  }
}

void main() {
  testWidgets('429 on resend starts a Retry-After cooldown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_ThrottledAuth.new)],
        child: const MaterialApp(home: OtpScreen()),
      ),
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(OtpScreen)));
    container.read(pendingVerificationControllerProvider.notifier).value =
        (email: 'a@b.co', token: 't');
    await tester.pump();

    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(find.text('Resend code in 30s'), findsOneWidget);
    expect(find.text('Too many attempts. Try again in 30 seconds.'),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Resend code'), findsOneWidget);
  });
}
