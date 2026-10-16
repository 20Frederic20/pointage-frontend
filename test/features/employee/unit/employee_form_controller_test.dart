import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

const draft = EmployeeDraft(userId: 'usr1', directoryId: 'dir1', employeeNumber: 'EMP0000099');

void main() {
  late FakeEmployeeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeEmployeeRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    container.listen(employeeFormControllerProvider, (_, _) {}); // garde le provider autoDispose en vie
  });

  test('a successful submit returns the employee and refreshes the list', () async {
    final created = await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(created?.employeeNumber, 'EMP0000099');
    expect(repo.lastDraft, same(draft));
    expect(container.read(employeeFormControllerProvider).submitting, isFalse);
    expect(container.read(employeeFormControllerProvider).error, isNull);
    await pumpEventQueue();
    expect(repo.calls, isNotEmpty);
  });

  test('a rejected submit returns null and keeps the backend message', () async {
    repo.createError = ApiException('Ce matricule est déjà utilisé.', status: 409);
    final created = await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(created, isNull);
    expect(container.read(employeeFormControllerProvider).error, 'Ce matricule est déjà utilisé.');
    expect(container.read(employeeFormControllerProvider).submitting, isFalse);
  });

  test('a network failure gives a creation-specific message', () async {
    repo.createError = Exception('socket');
    await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(container.read(employeeFormControllerProvider).error, 'Création impossible, vérifiez la connexion.');
  });
}
