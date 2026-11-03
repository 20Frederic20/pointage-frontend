import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/main_admin.dart';

void main() {
  test('« Annuaires » is in the menu of an ADMIN only', () {
    List<String> labels(Role role) => adminMenus(role).map((m) => m.label).toList();
    expect(labels(Role.admin), contains('Annuaires'));
    for (final role in [Role.hr, Role.manager, Role.payroll]) {
      expect(labels(role), isNot(contains('Annuaires')));
    }
    expect(labels(Role.hr), ['Employés', 'Anomalies', 'Pointages']);
  });
}
