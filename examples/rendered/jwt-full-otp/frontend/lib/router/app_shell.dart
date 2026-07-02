import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Shared chrome for every authenticated route, mounted by the ShellRoute in
/// app_router.dart. Screens below it (`child`) are just their content — no
/// Scaffold/AppBar of their own — so adding a new authed screen is one route
/// entry, not a copy of the app bar + sign-out wiring.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JWT Full OTP App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: child,
    );
  }
}
