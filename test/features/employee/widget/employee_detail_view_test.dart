import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_detail_view.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  final overrides = [fakeSession(), employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository())];

  testWidgets('shows the employee fields', (tester) async {
    await pumpAtWidth(tester, 380, const Scaffold(body: EmployeeDetailView(id: 'emp3')), overrides: overrides);
    expect(find.text('EMP0000003'), findsOneWidget);
    expect(find.text('0102030405'), findsOneWidget);
    expect(find.text('usr3'), findsOneWidget);
  });

  testWidgets('an unknown employee shows "Employé introuvable." with a retry', (tester) async {
    await pumpAtWidth(tester, 380, const Scaffold(body: EmployeeDetailView(id: 'emp999')), overrides: overrides);
    expect(find.text('Employé introuvable.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('the panel closes', (tester) async {
    var closed = false;
    await pumpAtWidth(
      tester,
      380,
      Scaffold(body: EmployeeDetailPanel(id: 'emp3', onClose: () => closed = true)),
      overrides: overrides,
    );
    await tester.tap(find.byTooltip('Fermer'));
    expect(closed, isTrue);
  });
}
