import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_provider.dart';
import 'features/punch/punch_screen.dart';

void main() => runApp(const ProviderScope(child: PointageApp()));

class PointageApp extends ConsumerWidget {
  const PointageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Pointage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: switch (session) {
        AsyncData(value: null) => const LoginScreen(),
        AsyncData() => const PunchScreen(),
        // build() ne lève jamais : seul le chargement initial arrive ici.
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
