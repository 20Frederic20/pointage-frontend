import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

const draft = EmployeeDraft(email: 'ana@pointage.bj', directoryId: 'dir1', employeeNumber: 'EMP0000099');

void main() {
  late FakeEmployeeRepository repo;
  late ProviderContainer container;
  late ProviderSubscription<EmployeeFormState> formSub;

  setUp(() {
    repo = FakeEmployeeRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(), employeeRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    formSub = container.listen(employeeFormControllerProvider, (_, _) {}); // garde le provider autoDispose en vie
    container.listen(employeeControllerProvider, (_, _) {});
  });

  test('a successful submit returns the employee and refreshes the list', () async {
    final created = await container.read(employeeFormControllerProvider.notifier).submit(draft);
    expect(created?.employeeNumber, 'EMP0000099');
    expect(repo.lastDraft, same(draft));
    expect(container.read(employeeFormControllerProvider).submitting, isFalse);
    expect(container.read(employeeFormControllerProvider).error, isNull);
    await pumpEventQueue();
    expect(repo.calls, isNotEmpty);
    expect(container.read(employeeControllerProvider).total, 46);
  });

  test('a created employee is still returned when the form is disposed mid-request', () async {
    final gate = Completer<void>();
    repo.createGate = gate.future;
    final notifier = container.read(employeeFormControllerProvider.notifier);
    final pending = notifier.submit(draft);
    await pumpEventQueue();
    formSub.close(); // plus aucun écouteur : le provider autoDispose est détruit
    await pumpEventQueue();
    gate.complete();
    final created = await pending;
    expect(created?.employeeNumber, 'EMP0000099');
    await pumpEventQueue();
    expect(container.read(employeeControllerProvider).total, 46);
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
