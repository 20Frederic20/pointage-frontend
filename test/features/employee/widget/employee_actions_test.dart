import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/format.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/assignment_model.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_detail_view.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

Employee placed(int n, {bool isActive = true, Role role = Role.employee}) => Employee(
      id: 'emp$n',
      userId: 'usr$n',
      employeeNumber: 'EMP${n.toString().padLeft(7, '0')}',
      role: role,
      isActive: isActive,
      firstName: 'Ana',
      lastName: 'Dossou',
      companyDirectoryId: 'dir1',
      companyName: 'Société R',
      currentSiteId: 'sit1',
      currentSiteName: 'Siège Cotonou',
    );

void main() {
  late FakeEmployeeRepository repo;

  Future<void> show(WidgetTester tester,
      {Employee? employee, String role = 'HR', String userId = 'usr99', List<Assignment> assignments = const []}) async {
    repo = FakeEmployeeRepository([employee ?? placed(3)])..assignmentList = assignments;
    await pumpAtWidth(
      tester,
      800,
      Scaffold(body: EmployeeDetailView(id: (employee ?? placed(3)).id)),
      overrides: [
        fakeSession(role: role, userId: userId),
        employeeRepositoryProvider.overrideWithValue(repo),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ],
    );
  }

  testWidgets('the detail shows the name, the company and the current site', (tester) async {
    await show(tester);
    expect(find.text('Ana Dossou'), findsOneWidget);
    expect(find.text('Société R'), findsOneWidget);
    expect(find.text('Siège Cotonou'), findsOneWidget);
  });

  testWidgets('« Modifier » sends only the changed fields', (tester) async {
    await show(tester);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '0199999999');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect((repo.actions.single.$1, repo.actions.single.$2), ('update', 'emp3'));
    expect(repo.actions.single.$3, {'phone': '0199999999'});
    expect(find.text('Employé modifié.'), findsOneWidget);
  });

  testWidgets('the role list stops at the session role', (tester) async {
    await show(tester, role: 'MANAGER');
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-role')));
    await tester.pumpAndSettle();
    expect(find.text('Manager'), findsWidgets);
    expect(find.text('RH'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  testWidgets('the role cannot be changed on your own record', (tester) async {
    await show(tester, userId: 'usr3');
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    final field = tester.widget<DropdownButtonFormField<Role>>(find.byKey(const ValueKey('edit-role')));
    expect(field.onChanged, isNull);
  });

  testWidgets('« Désactiver » asks first and calls once, even on a double tap', (tester) async {
    await show(tester);
    await tester.tap(find.text('Désactiver'));
    await tester.pumpAndSettle();
    expect(find.text('Désactiver Ana Dossou ? Il ne pourra plus pointer.'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.actions, isEmpty);

    await tester.tap(find.text('Désactiver'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Désactiver');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.actions, [('deactivate', 'emp3', null)]);
    expect(find.text('Employé désactivé.'), findsOneWidget);
  });

  testWidgets('an inactive employee offers « Réactiver »', (tester) async {
    await show(tester, employee: placed(4, isActive: false));
    expect(find.text('Désactiver'), findsNothing);
    await tester.tap(find.text('Réactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Réactiver'));
    await tester.pumpAndSettle();
    expect(repo.actions, [('activate', 'emp4', null)]);
  });

  testWidgets('a refused action shows the server message', (tester) async {
    await show(tester);
    repo.actionError = ApiException('Vous ne pouvez pas vous désactiver vous-même.', status: 403);
    await tester.tap(find.text('Désactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Désactiver'));
    await tester.pumpAndSettle();
    expect(find.text('Vous ne pouvez pas vous désactiver vous-même.'), findsOneWidget);
  });

  testWidgets('« Affecter à un site » warns about the running assignment and starts today', (tester) async {
    await show(tester);
    await tester.tap(find.text('Affecter à un site'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(find.text("L'affectation actuelle à Siège Cotonou se terminera le "
        '${formatDate(today.subtract(const Duration(days: 1)))}.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assign-start')));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, today);
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final (name, id, args) = repo.actions.single;
    expect((name, id), ('assign', 'emp3'));
    final a = args as ({String directoryId, String siteId, DateTime startDate, DateTime? endDate});
    expect((a.directoryId, a.siteId, a.startDate, a.endDate), ('dir1', 'sit1', today, null));
    expect(find.text('Affectation enregistrée.'), findsOneWidget);
  });

  testWidgets('the history ends the running assignment', (tester) async {
    await show(tester, assignments: [
      Assignment(id: 'asg1', directoryId: 'dir1', directoryName: 'Direction générale', siteId: 'sit1',
          siteName: 'Siège Cotonou', startDate: DateTime(2026, 1, 1)),
    ]);
    await tester.ensureVisible(find.text('Terminer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((repo.actions.single.$1, repo.actions.single.$2), ('end', 'asg1'));
    expect(find.text('Affectation terminée.'), findsOneWidget);
  });

  for (final width in responsiveWidths) {
    testWidgets('$width px: the detail, its actions and its dialogs fit (mobile and web)', (tester) async {
      repo = FakeEmployeeRepository([placed(3)])
        ..assignmentList = [
          Assignment(id: 'asg1', directoryId: 'dir1', directoryName: 'Direction générale', siteId: 'sit1',
              siteName: 'Siège Cotonou', startDate: DateTime(2026, 1, 1)),
        ];
      await pumpAtWidth(
        tester,
        width,
        const Scaffold(body: EmployeeDetailView(id: 'emp3')),
        height: 800,
        overrides: [
          fakeSession(role: 'HR', userId: 'usr99'),
          employeeRepositoryProvider.overrideWithValue(repo),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
        ],
      );
      for (final action in ['Modifier', 'Désactiver', 'Affecter à un site']) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget, reason: action);
        await tester.tap(find.text('Annuler').last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
