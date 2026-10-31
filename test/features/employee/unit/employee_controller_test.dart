import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_controller.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeEmployeeRepository repo;
  late ProviderContainer container;
  EmployeeController controller() => container.read(employeeControllerProvider.notifier);
  EmployeeState state() => container.read(employeeControllerProvider);

  void setUpWith({String? token = 'tok', FakeEmployeeRepository? repository}) {
    repo = repository ?? FakeEmployeeRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(token: token), employeeRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
  }

  test('refresh loads the first page', () async {
    setUpWith();
    await controller().refresh();
    expect(state().items.map((e) => e.id).take(2), ['emp1', 'emp2']);
    expect((state().items.length, state().total, state().offset, state().loading), (20, 45, 0, false));
    expect(state().hasMore, isTrue);
  });

  test('goToPage replaces the items with that page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(2);
    expect(state().items.map((e) => e.id), ['emp41', 'emp42', 'emp43', 'emp44', 'emp45']);
    expect((state().offset, state().page, state().pageCount, state().hasMore), (40, 2, 3, false));
  });

  test('goToPage outside the pages does nothing', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(3);
    await controller().goToPage(-1);
    expect(repo.calls, hasLength(1));
  });

  test('setFilters sends the filters and starts again from the first page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(1);
    await controller().setFilters(const EmployeeFilters(isActive: true, role: Role.employee));
    expect(repo.calls.last.offset, 0);
    expect(repo.calls.last.filters.role, Role.employee);
    expect(state().offset, 0);
  });

  test('loadMore appends the next page and stops when everything is loaded', () async {
    setUpWith();
    await controller().refresh();
    await controller().loadMore();
    expect((state().items.length, state().offset), (40, 0));
    await controller().loadMore();
    expect(state().items.length, 45);
    await controller().loadMore();
    expect(repo.calls, hasLength(3));
    expect(state().hasMore, isFalse);
  });

  test('loadMore ignores a second call while the first is running', () async {
    setUpWith();
    await controller().refresh();
    await Future.wait([controller().loadMore(), controller().loadMore()]);
    expect(repo.calls, hasLength(2));
    expect(state().items.length, 40);
  });

  test('a failure keeps a readable message, the next refresh clears it', () async {
    setUpWith();
    repo.listError = ApiException('Erreur serveur (500)', status: 500);
    await controller().refresh();
    expect((state().error, state().loading), ('Erreur serveur (500)', false));
    expect(state().items, isEmpty);
    repo.listError = null;
    await controller().refresh();
    expect(state().error, isNull);
    expect(state().items, hasLength(20));
  });

  test('an older response arriving after a newer one is ignored', () async {
    setUpWith();
    final first = Completer<void>();
    repo.beforeReturn = (call) => call == 0 ? first.future : Future.value();
    final slow = controller().setFilters(const EmployeeFilters(role: Role.manager));
    await controller().setFilters(const EmployeeFilters());
    first.complete();
    await slow;
    expect(state().filters.role, isNull);
    expect(state().total, 45);
  });

  test('refresh on a page that no longer exists falls back to the last page', () async {
    setUpWith();
    await controller().refresh();
    await controller().goToPage(2);
    repo.all.removeRange(30, 45); // il reste 30 employés : 2 pages
    await controller().refresh();
    expect((state().offset, state().items.length, state().total), (20, 10, 30));
  });

  test('an ended session stops loading with an explicit message', () async {
    setUpWith(token: null);
    await controller().refresh();
    expect(repo.calls, isEmpty);
    expect(state().loading, isFalse);
    expect(state().error, 'Session expirée, reconnectez-vous.');
  });

  test('a response pending when the controller rebuilds is discarded', () async {
    setUpWith();
    final gate = Completer<void>();
    repo.beforeReturn = (_) => gate.future;
    final pending = controller().refresh();
    await Future<void>.delayed(Duration.zero);
    container.invalidate(employeeControllerProvider);
    expect(state().items, isEmpty);
    gate.complete();
    await pending;
    expect(state().items, isEmpty);
    expect((state().total, state().loading), (0, false));
  });

  test('employeeErrorMessage', () {
    expect(employeeErrorMessage(ApiException('x', status: 404)), 'Employé introuvable.');
    expect(employeeErrorMessage(ApiException('Ce matricule est déjà utilisé.', status: 409)), 'Ce matricule est déjà utilisé.');
    expect(employeeErrorMessage(TimeoutException('t')), 'Connexion au serveur impossible, réessayez.');
  });
}
