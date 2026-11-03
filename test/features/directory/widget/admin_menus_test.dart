import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/admin/admin_routes.dart';
import 'package:pointage/core/role.dart';

void main() {
  test('« Annuaires » is in the menu of an ADMIN only', () {
    List<String> labels(Role role) => [
          for (final g in navGroupsFor(role))
            for (final i in g.items) i.label,
        ];
    expect(labels(Role.admin), contains('Annuaires'));
    for (final role in [Role.hr, Role.manager, Role.payroll]) {
      expect(labels(role), isNot(contains('Annuaires')));
    }
    expect(labels(Role.hr), ['Tableau de bord', 'Employés', 'Anomalies', 'Pointages']);
  });
}
