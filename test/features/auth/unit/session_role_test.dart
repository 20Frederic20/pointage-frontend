import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/auth/session_provider.dart';

String jwtWith(Map<String, dynamic> payload) {
  String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.${enc(payload)}.sig';
}

Session sessionWith(String token) =>
    Session(accessToken: token, refreshToken: 'r', accessExpiresAt: DateTime(2100), identifier: 'x');

void main() {
  test('the role is read from the JWT payload', () {
    final s = sessionWith(jwtWith({'sub': 'u1', 'role': 'HR', 'typ': 'access'}));
    expect(s.role, Role.hr);
    expect(s.isResponsible, isTrue);
  });

  test('a garbage token falls back to employee', () {
    for (final t in ['tok', '', 'a.b.c', 'a.!!!.c', jwtWith({'role': 'NOPE'}), jwtWith({'sub': 'u'})]) {
      final s = sessionWith(t);
      expect(s.role, Role.employee, reason: t);
      expect(s.isResponsible, isFalse);
    }
  });

  test('the employee record and the user are read from the JWT', () {
    final s = sessionWith(jwtWith({'sub': 'u1', 'role': 'HR', 'employee_id': 'emp2'}));
    expect((s.userId, s.employeeId), ('u1', 'emp2'));
    expect((sessionWith('tok').userId, sessionWith('tok').employeeId), (null, null));
  });

  test('the company name survives a save and a reload', () {
    final s = Session(accessToken: 't', refreshToken: 'r', accessExpiresAt: DateTime(2100), identifier: 'x',
        companyName: 'Société B');
    expect(Session.fromJson(s.toJson()).companyName, 'Société B');
    expect(Session.fromJson({...s.toJson()}..remove('companyName')).companyName, isNull);
  });
}
