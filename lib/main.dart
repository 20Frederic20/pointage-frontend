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
    final employeeNumber = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Pointage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: employeeNumber == null ? const LoginScreen() : const PunchScreen(),
    );
  }
}
