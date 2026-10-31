import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/directory/directory_model.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';

const _employee = {
  'id': 'emp1', 'role': 'EMPLOYEE', 'employeeNumber': 'EMP0000001', 'isActive': true, 'userId': 'usr1',
  'firstName': 'Ana', 'lastName': 'Dossou', 'companyDirectoryId': 'dir1', 'companyName': 'Société R',
  'currentSiteId': 'site2', 'currentSiteName': 'Agence Nord', 'currentAssignmentEndDate': '2026-12-31',
};
const _assignment = {
  'id': 'asg1', 'employeeId': 'emp1', 'directoryId': 'dir2', 'directoryName': 'Agence', 'siteId': 'site2',
  'siteName': 'Agence Nord', 'startDate': '2026-11-03', 'endDate': null,
};

void main() {
  late List<http.Request> sent;
  EmployeeRepository repo(Object body, {int status = 200}) {
    sent = [];
    return EmployeeRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    })));
  }

  Map<String, dynamic> bodyOf(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  test('Employee reads the names, the company and the current site', () {
    final e = Employee.fromJson(_employee);
    expect((e.firstName, e.lastName, e.companyName, e.currentSiteName), ('Ana', 'Dossou', 'Société R', 'Agence Nord'));
    expect(e.currentAssignmentEndDate, DateTime(2026, 12, 31));
    expect(e.displayName, 'Ana Dossou');
    final bare = Employee.fromJson({'id': 'e', 'role': 'EMPLOYEE', 'employeeNumber': 'EMP9', 'isActive': true, 'userId': 'u'});
    expect((bare.companyName, bare.currentSiteName, bare.displayName), (null, null, 'EMP9'));
  });

  test('a new draft is active by default', () {
    expect(const EmployeeDraft(email: 'a@b.bj', directoryId: 'd', employeeNumber: 'EMP0000001').isActive, isTrue);
  });

  test('update patches only the fields given', () async {
    final e = await repo(_employee).update('tok', 'emp1', phone: '0197000000', role: Role.manager);
    expect((sent.single.method, sent.single.url.path), ('PATCH', '/employees/emp1'));
    expect(bodyOf(sent.single), {'phone': '0197000000', 'role': 'MANAGER'});
    expect(e.id, 'emp1');
  });

  test('deactivate and activate post to their routes', () async {
    await repo(_employee).deactivate('tok', 'emp1');
    expect(sent.single.url.path, '/employees/emp1/deactivate');
    await repo(_employee).activate('tok', 'emp1');
    expect(sent.single.url.path, '/employees/emp1/activate');
  });

  test('assignments lists by employee with names', () async {
    final list = await repo([_assignment]).assignments('tok', 'emp1');
    expect(sent.single.url.queryParameters, {'employee_id': 'emp1'});
    expect((list.single.siteName, list.single.startDate, list.single.endDate), ('Agence Nord', DateTime(2026, 11, 3), null));
  });

  test('assign sends the snake_case body the backend expects', () async {
    await repo(_assignment).assign('tok',
        employeeId: 'emp1', directoryId: 'dir2', siteId: 'site2', startDate: DateTime(2026, 11, 3));
    expect(sent.single.url.path, '/employee-assignments');
    expect(bodyOf(sent.single),
        {'employee_id': 'emp1', 'directory_id': 'dir2', 'site_id': 'site2', 'start_date': '2026-11-03'});
  });

  test('endAssignment posts the end date', () async {
    await repo(_assignment).endAssignment('tok', 'asg1', DateTime(2026, 11, 30));
    expect(sent.single.url.path, '/employee-assignments/asg1/end');
    expect(bodyOf(sent.single), {'end_date': '2026-11-30'});
  });

  test('create says whether the account was reused', () async {
    final created = await repo({..._employee, 'accountReused': true}, status: 201)
        .create('tok', const EmployeeDraft(email: 'a@b.bj', directoryId: 'dir1', employeeNumber: 'EMP0000001'));
    expect((created.id, created.accountReused), ('emp1', true));
  });

  test('a directory without parent is a company', () {
    expect(Directory.fromJson({'id': 'd1', 'name': 'R', 'code': 'R', 'parentDirectoryId': null}).isCompany, isTrue);
    final child = Directory.fromJson({'id': 'd2', 'name': 'A', 'code': 'A', 'parentDirectoryId': 'd1'});
    expect((child.isCompany, child.parentDirectoryId), (false, 'd1'));
  });
}
