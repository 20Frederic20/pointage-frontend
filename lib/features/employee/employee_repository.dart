import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import '../../core/role.dart';
import '../punch/punch_repository.dart' show TimeEntry, newIdempotencyKey;
import 'assignment_model.dart';
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

  /// [Employee.accountReused] : l'email avait déjà un compte (autre entreprise).
  Future<Employee> create(String accessToken, EmployeeDraft draft) async =>
      Employee.fromJson(await _api.post('/employees/onboard', draft.toJson(), accessToken: accessToken));

  /// Nom (commun à toutes les entreprises), téléphone et rôle ; seuls les champs donnés sont envoyés.
  Future<Employee> update(String accessToken, String id,
          {String? firstName, String? lastName, String? phone, Role? role}) async =>
      Employee.fromJson(await _api.patch(
          '/employees/$id',
          {
            'firstName': ?firstName,
            'lastName': ?lastName,
            'phone': ?phone,
            'role': ?role?.wire,
          },
          accessToken: accessToken));

  Future<Employee> deactivate(String accessToken, String id) async =>
      Employee.fromJson(await _api.post('/employees/$id/deactivate', {}, accessToken: accessToken));

  Future<Employee> activate(String accessToken, String id) async =>
      Employee.fromJson(await _api.post('/employees/$id/activate', {}, accessToken: accessToken));

  /// Les affectations, la plus récente d'abord.
  Future<List<Assignment>> assignments(String accessToken, String employeeId) async {
    final data = await _api.get('/employee-assignments', accessToken: accessToken, query: {'employee_id': employeeId});
    return [for (final a in data as List) Assignment.fromJson(a as Map<String, dynamic>)];
  }

  /// Une mutation quand une affectation est en cours : elle s'arrête la veille (backend).
  Future<Assignment> assign(String accessToken,
          {required String employeeId,
          required String directoryId,
          required String siteId,
          required DateTime startDate,
          DateTime? endDate}) async =>
      Assignment.fromJson(await _api.post(
          '/employee-assignments',
          {
            'employee_id': employeeId,
            'directory_id': directoryId,
            'site_id': siteId,
            'start_date': isoDate(startDate),
            if (endDate != null) 'end_date': isoDate(endDate),
          },
          accessToken: accessToken));

  Future<Assignment> endAssignment(String accessToken, String assignmentId, DateTime endDate) async =>
      Assignment.fromJson(await _api.post(
          '/employee-assignments/$assignmentId/end', {'end_date': isoDate(endDate)},
          accessToken: accessToken));

  /// Pointe pour [employeeId] (responsable). Le serveur décide arrivée ou départ.
  /// [idempotencyKey] : à réutiliser pour renvoyer le même pointage (réponse perdue) ; neuve si absente.
  Future<TimeEntry> punchFor(String accessToken, String employeeId, {String? idempotencyKey}) async =>
      TimeEntry.fromJson(await _api.post(
          '/employees/$employeeId/time-entries', {'idempotencyKey': idempotencyKey ?? newIdempotencyKey()},
          accessToken: accessToken));
}

final employeeRepositoryProvider = Provider((ref) => EmployeeRepository(ref.watch(apiClientProvider)));
