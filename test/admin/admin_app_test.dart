import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/admin/admin_app.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';
import 'package:pointage/features/anomaly/screens/anomaly_web_screen.dart';
import 'package:pointage/features/auth/login_screen.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/directory/screens/directory_web_screen.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_web_screen.dart';
import 'package:pointage/features/user/user_repository.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

import '../helpers/anomaly_fakes.dart';
import '../helpers/directory_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/work_time_fakes.dart';

void main() {
  List<Override> overrides({String role = 'HR'}) => [
        fakeSession(role: role, userId: 'usr9'),
        employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryAdminRepository()),
        anomalyRepositoryProvider.overrideWithValue(FakeAnomalyRepository()),
        workTimeRepositoryProvider.overrideWithValue(FakeWorkTimeRepository()),
      ];

  Future<void> pumpAdmin(WidgetTester tester, {double width = 1440, List<Override>? with_}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: with_ ?? overrides(), retry: (_, _) => null, child: const AdminApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('without a session the back-office shows the sign-in screen', (tester) async {
    await pumpAdmin(tester, with_: [signedOutSession()]);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the sidebar groups the menus and opens each screen', (tester) async {
    await pumpAdmin(tester);
    for (final group in ['VUE D\'ENSEMBLE', 'GESTION']) {
      expect(find.text(group), findsOneWidget, reason: group);
    }
    expect(find.text('ADMINISTRATION'), findsNothing, reason: 'Annuaires is ADMIN-only');
    expect(find.text('Annuaires'), findsNothing);

    await tester.tap(find.text('Employés').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeWebScreen), findsOneWidget);

    await tester.tap(find.text('Anomalies').first);
    await tester.pumpAndSettle();
    expect(find.byType(AnomalyWebScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ADMIN also sees « Annuaires »', (tester) async {
    await pumpAdmin(tester, with_: overrides(role: 'ADMIN'));
    expect(find.text('ADMINISTRATION'), findsOneWidget);
    await tester.tap(find.text('Annuaires'));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryWebScreen), findsOneWidget);
  });

  testWidgets('the top bar shows the current page and the search trigger', (tester) async {
    await pumpAdmin(tester);
    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Rechercher…'), findsOneWidget);
  });

  testWidgets('360 px: a drawer replaces the sidebar, without overflow', (tester) async {
    await pumpAdmin(tester, width: 360);
    expect(find.text('VUE D\'ENSEMBLE'), findsNothing);
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();
    expect(find.text('GESTION'), findsOneWidget);
    await tester.tap(find.text('Pointages').last);
    await tester.pumpAndSettle();
    expect(find.text('GESTION'), findsNothing, reason: 'the drawer closes after a choice');
    expect(tester.takeException(), isNull);
  });
}
