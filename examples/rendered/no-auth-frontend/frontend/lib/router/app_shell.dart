import 'package:flutter/material.dart';

/// Shared chrome for every route, mounted by the ShellRoute in
/// app_router.dart. Screens below it (`child`) are just their content — no
/// Scaffold/AppBar of their own — so adding a new screen is one route
/// entry, not a copy of the app bar.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('No Auth App'),
      ),
      body: child,
    );
  }
}
