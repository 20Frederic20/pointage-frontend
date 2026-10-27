import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_mobile_screen.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/employee/widgets/punch_for_employee_button.dart';
import 'package:pointage/features/punch/punch_repository.dart';
import 'package:pointage/features/punch/punch_screen.dart';

import '../../../helpers/assisted_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  setUp(() => repo = FakeEmployeeRepository());

  Future<void> pumpButton(WidgetTester tester, {bool isActive = true}) => pumpAtWidth(
        tester,
        400,
        Scaffold(body: Center(child: PunchForEmployeeButton(employee: fakeEmployee(7, isActive: isActive)))),
        overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
      );

  testWidgets('confirm calls punchFor once, even on a double tap', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    expect(find.text('Faire pointer EMP0000007 maintenant ?'), findsOneWidget);

    final confirm = find.widgetWithText(FilledButton, 'Faire pointer');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repo.punched, ['emp7']);
    expect(find.text('Entrée enregistrée pour EMP0000007 à 08:05'), findsOneWidget);
  });

  testWidgets('cancel does not call punchFor', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.punched, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an OUT entry says « Sortie »', (tester) async {
    repo.punchType = 'OUT';
    await pumpButton(tester);
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Faire pointer'));
    await tester.pumpAndSettle();
    expect(find.text('Sortie enregistrée pour EMP0000007 à 08:05'), findsOneWidget);
  });

  testWidgets('an error shows the ApiException message', (tester) async {
    repo.punchError = ApiException('Vous ne pouvez pas pointer pour vous-même.', status: 409);
    await pumpButton(tester);
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Faire pointer'));
    await tester.pumpAndSettle();
    expect(find.text('Vous ne pouvez pas pointer pour vous-même.'), findsOneWidget);
  });

  Future<void> confirmPunch(WidgetTester tester) async {
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Faire pointer'));
    await tester.pumpAndSettle();
  }

  testWidgets('a retry after a network failure reuses the idempotency key', (tester) async {
    repo.punchError = Exception('timeout');
    await pumpButton(tester);
    await confirmPunch(tester);
    expect(find.text('Connexion au serveur impossible, réessayez.'), findsOneWidget);

    repo.punchError = null;
    await confirmPunch(tester);
    expect(repo.punchKeys, hasLength(2));
    expect(repo.punchKeys.first, isNotNull);
    expect(repo.punchKeys.last, repo.punchKeys.first);

    await confirmPunch(tester); // après un succès : nouveau pointage, nouvelle clé
    expect(repo.punchKeys.last, isNotNull);
    expect(repo.punchKeys.last, isNot(repo.punchKeys[1]));
  });

  testWidgets('an ApiException drops the idempotency key', (tester) async {
    repo.punchError = ApiException('Vous ne pouvez pas pointer pour vous-même.', status: 409);
    await pumpButton(tester);
    await confirmPunch(tester);
    repo.punchError = null;
    await confirmPunch(tester);
    expect(repo.punchKeys, hasLength(2));
    expect(repo.punchKeys.last, isNot(repo.punchKeys.first));
  });

  testWidgets('the button is disabled while the request runs', (tester) async {
    final gate = Completer<void>();
    repo.punchGate = gate.future;
    await pumpButton(tester);
    await tester.tap(find.byType(PunchForEmployeeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Faire pointer'));
    await tester.pump();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNotNull);
  });

  testWidgets('absent for an inactive employee', (tester) async {
    await pumpButton(tester, isActive: false);
    expect(find.byType(IconButton), findsNothing);
  });

  group('EmployeeMobileScreen', () {
    testWidgets('lists employees with the button and searches by matricule', (tester) async {
      await pumpAtWidth(tester, 400, const EmployeeMobileScreen(),
          overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)]);
      expect(find.byType(EmployeeCard), findsWidgets);
      expect(find.byType(PunchForEmployeeButton), findsWidgets);

      await tester.enterText(find.byType(TextField), 'EMP0000003');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeCard), findsOneWidget);
      expect(find.descendant(of: find.byType(EmployeeCard), matching: find.text('EMP0000003')), findsOneWidget);
    });
  });

  group('PunchScreen « Employés » action', () {
    Future<void> pumpPunch(WidgetTester tester, String? role) => pumpAtWidth(
          tester,
          400,
          const PunchScreen(),
          overrides: [
            fakeSession(role: role),
            punchRepositoryProvider.overrideWithValue(FakePunchRepository()),
            employeeRepositoryProvider.overrideWithValue(repo),
          ],
          settle: false,
        );

    testWidgets('visible with an HR session and opens the screen', (tester) async {
      await pumpPunch(tester, 'HR');
      await tester.pump();
      expect(find.byTooltip('Employés'), findsOneWidget);
      await tester.tap(find.byTooltip('Employés'));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeMobileScreen), findsOneWidget);
    });

    testWidgets('absent with an EMPLOYEE session', (tester) async {
      await pumpPunch(tester, 'EMPLOYEE');
      await tester.pump();
      expect(find.byTooltip('Employés'), findsNothing);
    });

    testWidgets('the default session keeps working (employee)', (tester) async {
      await pumpPunch(tester, null);
      await tester.pump();
      expect(find.byTooltip('Employés'), findsNothing);
    });
  });
}
