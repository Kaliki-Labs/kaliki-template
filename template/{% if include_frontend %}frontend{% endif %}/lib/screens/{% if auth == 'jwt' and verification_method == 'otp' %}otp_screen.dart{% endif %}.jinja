import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// Collects the 6-digit code emailed after signup and verifies the account.
/// On success the user is signed in and the router redirects home.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _ticker;
  int _cooldown = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_code.text.trim());
  }

  void _startCooldown(Duration wait) {
    _ticker?.cancel();
    setState(() => _cooldown = wait.inSeconds < 1 ? 1 : wait.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).resendOtp();
      messenger.showSnackBar(const SnackBar(content: Text('Code sent.')));
      _startCooldown(defaultRetryAfter);
    } on Object catch (e) {
      final wait = retryAfterOf(e);
      if (wait != null) _startCooldown(wait);
      messenger.showSnackBar(
        SnackBar(
          content: Text(authErrorMessage(e, 'Could not resend the code.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final pending = ref.watch(pendingVerificationControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authErrorMessage(
                next.error,
                'Invalid or expired code. Try again.',
              ),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                pending == null
                    ? 'Enter the 6-digit code we emailed you.'
                    : 'Enter the 6-digit code we sent to ${pending.email}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Verification code',
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Verify',
                loading: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cooldown > 0 || pending == null ? null : _resend,
                child: Text(
                  _cooldown > 0
                      ? 'Resend code in ${_cooldown}s'
                      : 'Resend code',
                ),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(pendingVerificationControllerProvider.notifier)
                      .clear();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
