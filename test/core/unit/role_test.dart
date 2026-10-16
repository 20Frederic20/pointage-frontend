import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';

void main() {
  test('every backend role has a French label', () {
    expect(Role.values.map((r) => r.wire), ['EMPLOYEE', 'MANAGER', 'HR', 'PAYROLL', 'ADMIN']);
    expect(Role.fromWire('HR').label, 'RH');
  });

  test('an unknown role is a format error, not a silent default', () {
    expect(() => Role.fromWire('BOSS'), throwsFormatException);
  });
}
