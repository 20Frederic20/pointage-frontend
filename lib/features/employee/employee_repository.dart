import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'employee_model.dart';

/// Routes `/employees` du backend.
class EmployeeRepository {
  EmployeeRepository(this._api);
  final ApiClient _api;

  Future<Paged<Employee>> list(
    String accessToken, {
    EmployeeFilters filters = const EmployeeFilters(),
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get('/employees', accessToken: accessToken, query: {
      if (filters.search.isNotEmpty) 'employee_number': filters.search,
      if (filters.role != null) 'role': filters.role!.wire,
      if (filters.isActive != null) 'is_active': '${filters.isActive}',
      'limit': '$limit',
      'offset': '$offset',
    });
    return Paged.fromJson(data as Map<String, dynamic>, Employee.fromJson);
  }

  Future<Employee> getById(String accessToken, String id) async =>
      Employee.fromJson(await _api.get('/employees/$id', accessToken: accessToken) as Map<String, dynamic>);

  Future<Employee> create(String accessToken, EmployeeDraft draft) async =>
      Employee.fromJson(await _api.post('/employees/onboard', draft.toJson(), accessToken: accessToken));
}

final employeeRepositoryProvider = Provider((ref) => EmployeeRepository(ref.watch(apiClientProvider)));
