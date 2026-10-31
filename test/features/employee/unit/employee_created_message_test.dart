import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/screens/employee_create_page.dart';

Employee created({required bool reused}) => Employee(
    id: 'emp1', userId: 'usr1', employeeNumber: 'EMP0000001', role: Role.employee, isActive: true,
    accountReused: reused);

void main() {
  test('a new account gets the usual message', () {
    expect(createdMessage(created(reused: false)), 'Employé EMP0000001 créé');
  });

  test('an existing account says a new record was added in this company', () {
    expect(createdMessage(created(reused: true)),
        'Ce compte existait déjà : une nouvelle fiche a été créée dans cette entreprise.');
  });
}
