import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/admin_shell.dart';
import 'core/layout/nav_item.dart';
import 'core/theme.dart';
import 'features/anomaly/screens/anomaly_web_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_provider.dart';
import 'features/employee/screens/employee_web_screen.dart';

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
void main() => runApp(const ProviderScope(child: AdminApp()));

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Pointage — Administration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: switch (session) {
        AsyncData(value: null) => const LoginScreen(),
        AsyncData() => AdminShell(menus: [
            NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeWebScreen()),
            NavItem(label: 'Anomalies', icon: Icons.report_problem_outlined, builder: (_) => const AnomalyWebScreen()),
          ]),
        // build() ne lève jamais : seul le chargement initial arrive ici.
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
