import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/shadcn.dart';

import '../core/role.dart';
import '../features/anomaly/screens/anomaly_web_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session_provider.dart';
import '../features/directory/screens/directory_web_screen.dart';
import '../features/employee/screens/employee_web_screen.dart';
import '../features/work_time/screens/work_time_web_screen.dart';
import 'admin_routes.dart';
import 'admin_shell.dart';
import 'dashboard/dashboard_screen.dart';

/// Thème blanc uniquement : l'ardoise claire de Kite.
final adminTheme = ShadThemeData(brightness: Brightness.light, colorScheme: const ShadSlateColorScheme.light());

/// Relance la redirection quand la session change (connexion, déconnexion).
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  final router = GoRouter(
    initialLocation: AdminPaths.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Session pas encore chargée : on garde l'adresse demandée (lien direct, F5) jusqu'au rafraîchissement.
      if (ref.read(sessionProvider) case AsyncLoading(hasValue: false)) return null;
      final session = ref.read(sessionProvider).value;
      final atSignIn = state.matchedLocation == AdminPaths.signIn;
      if (session == null) return atSignIn ? null : AdminPaths.signIn;
      if (atSignIn) return AdminPaths.dashboard;
      if (state.matchedLocation.startsWith(AdminPaths.directories) && session.role != Role.admin) {
        return AdminPaths.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: AdminPaths.signIn, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AdminPaths.dashboard, pageBuilder: (_, _) => _page(const DashboardScreen())),
          GoRoute(path: AdminPaths.employees, pageBuilder: (_, _) => _page(const EmployeeWebScreen())),
          GoRoute(path: AdminPaths.anomalies, pageBuilder: (_, _) => _page(const AnomalyWebScreen())),
          GoRoute(path: AdminPaths.timeEntries, pageBuilder: (_, _) => _page(const WorkTimeWebScreen())),
          GoRoute(path: AdminPaths.directories, pageBuilder: (_, _) => _page(const DirectoryWebScreen())),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Zone de contenu : 1400 px au plus, marges de 16 px (téléphone) ou 24 px, sans animation entre menus.
NoTransitionPage<void> _page(Widget screen) => NoTransitionPage(child: _Page(child: screen));

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: SizedBox.expand(
          key: const Key('admin-page'),
          child: Padding(padding: EdgeInsets.all(narrow ? 16 : 24), child: child),
        ),
      ),
    );
  }
}

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Premier chargement de la session (stockage sécurisé, rafraîchissement) : rien à afficher encore.
    // Une seule application routeur, pour ne pas réécrire l'adresse du navigateur pendant l'attente.
    final session = ref.watch(sessionProvider);
    final loading = session.isLoading && !session.hasValue;
    return ShadApp.router(
      builder: (context, child) =>
          loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : child!,
      title: 'Pointage — Administration',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: adminTheme,
      // Tableaux plus serrés, comme ceux de Kite : les colonnes tiennent à 1440 px sans défiler.
      materialThemeBuilder: (_, theme) => theme.copyWith(
        dataTableTheme: theme.dataTableTheme.copyWith(columnSpacing: 24, horizontalMargin: 16),
      ),
      routerConfig: ref.watch(adminRouterProvider),
    );
  }
}
