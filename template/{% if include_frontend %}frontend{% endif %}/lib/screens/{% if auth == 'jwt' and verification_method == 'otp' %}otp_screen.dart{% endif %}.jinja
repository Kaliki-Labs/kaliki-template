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

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).verifyOtp(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final pending = ref.watch(pendingVerificationControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired code. Try again.')),
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
