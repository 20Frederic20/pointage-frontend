import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

const _employeeJson = {
  'id': 'emp1', 'role': 'EMPLOYEE', 'employeeNumber': 'EMP0000001', 'isActive': true, 'phone': null, 'userId': 'usr1',
};

void main() {
  late List<http.Request> sent;
  EmployeeRepository repo(int status, Object body) {
    sent = [];
    return EmployeeRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    })));
  }

  test('list sends filters and paging as backend query parameters', () async {
    final page = await repo(200, {'items': [_employeeJson], 'total': 41}).list(
      'tok',
      filters: const EmployeeFilters(search: 'EMP0000001', role: Role.manager, isActive: false),
      offset: 20,
    );
    expect(sent.single.url.queryParameters, {
      'employee_number': 'EMP0000001', 'role': 'MANAGER', 'is_active': 'false', 'limit': '20', 'offset': '20',
    });
    expect(page.total, 41);
    expect(page.items.single.employeeNumber, 'EMP0000001');
  });

  test('list without filters only sends paging', () async {
    await repo(200, {'items': [], 'total': 0}).list('tok');
    expect(sent.single.url.queryParameters, {'limit': '20', 'offset': '0'});
  });

  test('getById reads one employee', () async {
    final e = await repo(200, _employeeJson).getById('tok', 'emp1');
    expect(sent.single.url.path, '/employees/emp1');
    expect(e.id, 'emp1');
  });

  test('getById surfaces a 404 as ApiException', () async {
    await expectLater(repo(404, {'detail': 'Employee not found'}).getById('tok', 'emp9'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
  });

  test('create posts the draft and returns the created employee', () async {
    final e = await repo(201, _employeeJson)
        .create('tok', const EmployeeDraft(userId: 'usr1', directoryId: 'dir1', employeeNumber: 'EMP0000001'));
    expect(sent.single.method, 'POST');
    expect(jsonDecode(sent.single.body), containsPair('user_id', 'usr1'));
    expect(e.id, 'emp1');
  });

  test('punchFor posts a fresh idempotency key each call and parses the entry', () async {
    final r = repo(201, {'entry_type': 'OUT', 'occured_at': '2026-10-27T08:05:00Z', 'validation_status': 'COUNTED'});
    final entry = await r.punchFor('tok', 'emp1');
    await r.punchFor('tok', 'emp1');
    expect(sent.first.method, 'POST');
    expect(sent.first.url.path, '/employees/emp1/time-entries');
    expect(entry.isIn, isFalse);
    final keys = sent.map((q) => (jsonDecode(q.body) as Map)['idempotencyKey']).toSet();
    expect(keys.length, 2);
    expect(keys.every((k) => k is String && k.isNotEmpty), isTrue);
  });
}
