import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/employee/widgets/employee_table.dart';
import 'package:pointage/features/employee/widgets/employee_toolbar.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  testWidgets('EmployeeTable shows "Créé le" only when asked, and reports taps', (tester) async {
    Employee? tapped;
    final employees = [fakeEmployee(1), fakeEmployee(2, role: Role.manager, isActive: false)];
    await pumpAtWidth(tester, 800, Scaffold(body: EmployeeTable(employees: employees, onTap: (e) => tapped = e)));
    expect(find.text('Créé le'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Inactif'), findsOneWidget);
    await tester.tap(find.text('EMP0000002'));
    expect(tapped?.id, 'emp2');

    await pumpAtWidth(tester, 800, Scaffold(body: EmployeeTable(employees: employees, onTap: (_) {}, showCreatedAt: false)));
    expect(find.text('Créé le'), findsNothing);
  });

  testWidgets('EmployeeCard shows number, role and status within a phone width', (tester) async {
    await pumpAtWidth(tester, 320, Scaffold(body: EmployeeCard(employee: fakeEmployee(1), onTap: () {})));
    expect(find.text('EMP0000001'), findsOneWidget);
    expect(find.text('Employé'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('EmployeeToolbar keeps the other criteria when one changes', (tester) async {
    EmployeeFilters? sent;
    await pumpAtWidth(
      tester,
      1200,
      Scaffold(
        body: EmployeeToolbar(
          filters: const EmployeeFilters(search: 'EMP0000001', isActive: true),
          onChanged: (f) => sent = f,
          onCreate: () {},
        ),
      ),
    );
    await tester.tap(find.text('Tous les rôles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RH').last);
    await tester.pumpAndSettle();
    expect((sent?.search, sent?.role, sent?.isActive), ('EMP0000001', Role.hr, true));
    expect(find.text('Nouvel employé'), findsOneWidget);
  });

  testWidgets('EmployeeToolbar compact: full-width fields and an icon button', (tester) async {
    await pumpAtWidth(
      tester,
      360,
      Scaffold(body: EmployeeToolbar(filters: const EmployeeFilters(), onChanged: (_) {}, onCreate: () {}, compact: true)),
    );
    expect(find.byTooltip('Nouvel employé'), findsOneWidget);
    expect(find.text('Nouvel employé'), findsNothing);
  });
}
