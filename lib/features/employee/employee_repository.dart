import 'package:pointage/core/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class Employee {
  Employee({required this.userId, required this.directoryId, required this.employeeNumber, this.role, this.phone });

  final String userId;
  final String directoryId;
  final String? role;
  final String employeeNumber;
  final String? phone;

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    userId: j["userId"] as String,
    directoryId: j["directoryId"] as String,
    role: j["role"] as String,
    employeeNumber: j["employeeNumber"] as String,
    phone: j["phone"] as String,
  );
}

class EmployeeRepository {
  EmployeeRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list(String accessToken) async {
    final data = await _api.get('/employees', accessToken: accessToken);

    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Employee> getbyId(String accessToken, String id) async {
    final data = await _api.get("/employees/$id", accessToken: accessToken);
    return Employee.fromJson(data);
  }

  Future<Employee> post(String accessToken, ) async {
    final data = await _api.post("/employees", {}, accessToken: accessToken);
    return Employee.fromJson(data);
  }
}

final employeeRepositoryProvider = Provider((ref) => EmployeeRepository(ref.watch(apiClientProvider)));