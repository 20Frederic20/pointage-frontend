import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/auth/session_provider.dart';
import 'package:pointage/features/employee/employee_repository.dart';


class EmployeeState {
  const EmployeeState({
    this.employees = const [],
    this.last,
    this.loading = false,
    this.error,
  });

  final List<Employee> employees;
  final Employee? last;
  final bool loading;
  final String? error;

  EmployeeState copyWith({
    List<Employee>? employees,
    Employee? last,
    bool? loading,
    String? error,
  }) {
    return EmployeeState(
      employees: employees ?? this.employees,
      last: last ?? this.last,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class EmployeeController extends Notifier<EmployeeState> {
  @override
  EmployeeState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier));

    return const EmployeeState();
  }

  Future<void> fetchEmployees() async {
    if (state.loading) return;

    // On active le chargement et on nettoie l'erreur
    state = state.copyWith(loading: true, error: null);

    try {
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) {
        state = state.copyWith(loading: false);
        return;
      }

      final list = await ref.read(employeeRepositoryProvider).get(token);

      state = state.copyWith(
        loading: false,
        employees: list,
        last: list.isNotEmpty ? list.last : null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: _message(e),
      );
    }
  }

}


String _message(Object e) => switch (e) {
      ApiException(code: 'NOT_FOUND') => "Aucune données trouvée",
      ApiException(:final message) => message,
      _ => 'Impossible de charger les données',
    };

final employeeControllerProvider = NotifierProvider<EmployeeController, EmployeeState>(EmployeeController.new);