import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: NoAuthAppApp()));
}

class NoAuthAppApp extends ConsumerWidget {
  const NoAuthAppApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'No Auth App',
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
    );
  }
}
