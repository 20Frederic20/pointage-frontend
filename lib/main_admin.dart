import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/admin_shell.dart';
import 'core/layout/nav_item.dart';
import 'core/role.dart';
import 'core/theme.dart';
import 'features/anomaly/screens/anomaly_web_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/directory/screens/directory_web_screen.dart';
import 'features/auth/session_provider.dart';
import 'features/employee/screens/employee_web_screen.dart';
import 'features/work_time/screens/work_time_web_screen.dart';

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
void main() => runApp(const ProviderScope(child: AdminApp()));

/// Menus du back-office ; « Annuaires » est réservé à l'ADMIN.
List<NavItem> adminMenus(Role role) => [
      NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeWebScreen()),
      NavItem(label: 'Anomalies', icon: Icons.report_problem_outlined, builder: (_) => const AnomalyWebScreen()),
      NavItem(label: 'Pointages', icon: Icons.schedule_outlined, builder: (_) => const WorkTimeWebScreen()),
      if (role == Role.admin)
        NavItem(label: 'Annuaires', icon: Icons.account_tree_outlined, builder: (_) => const DirectoryWebScreen()),
    ];

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
        AsyncData(:final value?) => AdminShell(menus: adminMenus(value.role)),
        // build() ne lève jamais : seul le chargement initial arrive ici.
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
