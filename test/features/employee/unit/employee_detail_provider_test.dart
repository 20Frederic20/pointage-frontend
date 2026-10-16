import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  ProviderContainer containerWith(FakeEmployeeRepository repo) => ProviderContainer.test(
        overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
        retry: (_, _) => null,
      );

  test('loads one employee', () async {
    final container = containerWith(FakeEmployeeRepository());
    final sub = container.listen(employeeDetailProvider('emp3'), (_, _) {});
    expect((await container.read(employeeDetailProvider('emp3').future)).employeeNumber, 'EMP0000003');
    sub.close();
  });

  test('an unknown id fails with the "not found" message', () async {
    final container = containerWith(FakeEmployeeRepository());
    final sub = container.listen(employeeDetailProvider('emp999'), (_, _) {});
    final error = await container.read(employeeDetailProvider('emp999').future).then<Object?>((_) => null, onError: (Object e) => e);
    expect(employeeErrorMessage(error!), 'Employé introuvable.');
    sub.close();
  });
}
