import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';

void main() {
  test('Employee reads the backend EmployeeResponse', () {
    final e = Employee.fromJson({
      'id': 'emp1',
      'role': 'MANAGER',
      'employeeNumber': 'EMP0000001',
      'isActive': true,
      'phone': null,
      'userId': 'usr1',
      'createdAt': '2026-10-16T08:30:00Z',
      'updatedAt': null,
    });
    expect(e.id, 'emp1');
    expect(e.role, Role.manager);
    expect(e.isActive, isTrue);
    expect(e.phone, isNull);
    expect(e.createdAt, DateTime.utc(2026, 10, 16, 8, 30).toLocal());
    expect(e.updatedAt, isNull);
  });

  test('EmployeeDraft sends snake_case and omits empty optional fields', () {
    const draft = EmployeeDraft(
        email: 'ana@pointage.bj', password: '', directoryId: 'dir1', employeeNumber: 'EMP0000001', phone: '');
    expect(draft.toJson(), {
      'email': 'ana@pointage.bj',
      'directory_id': 'dir1',
      'employee_number': 'EMP0000001',
      'role': 'EMPLOYEE',
      'is_active': true, // actif par défaut
    });
  });

  test('EmployeeDraft sends the optional fields when set', () {
    final draft = EmployeeDraft(
      email: 'ana@pointage.bj',
      password: 's3cret-pass',
      firstName: 'Ana',
      lastName: 'Dossou',
      directoryId: 'dir1',
      employeeNumber: 'EMP0000001',
      role: Role.hr,
      phone: '0102030405',
      isActive: true,
      siteId: 'sit1',
      assignmentStartDate: DateTime(2026, 3, 5),
    );
    expect(draft.toJson(), containsPair('assignment_start_date', '2026-03-05'));
    expect(draft.toJson(), containsPair('site_id', 'sit1'));
    expect(draft.toJson(), containsPair('phone', '0102030405'));
    expect(draft.toJson(), containsPair('role', 'HR'));
    expect(draft.toJson(), containsPair('password', 's3cret-pass'));
    expect(draft.toJson(), containsPair('first_name', 'Ana'));
    expect(draft.toJson(), containsPair('last_name', 'Dossou'));
  });

  test('EmployeeFilters is empty only without any criterion', () {
    expect(const EmployeeFilters().isEmpty, isTrue);
    expect(const EmployeeFilters(isActive: false).isEmpty, isFalse);
  });
}
