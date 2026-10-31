import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/auth/auth_repository.dart';

const _pair = {'status': 'authenticated', 'accessToken': 'a', 'refreshToken': 'r', 'tokenType': 'bearer', 'expiresIn': 900};
const _choice = {
  'status': 'selection_required',
  'selectionToken': 'sel',
  'employments': [
    {'employeeId': 'emp1', 'companyName': 'Société A', 'role': 'EMPLOYEE'},
    {'employeeId': 'emp2', 'companyName': null, 'role': 'HR'},
  ],
};

void main() {
  late List<http.Request> sent;
  AuthRepository repo(Object body) {
    sent = [];
    return AuthRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    })));
  }

  test('a token pair is an authenticated login', () async {
    final result = await repo(_pair).loginWithPassword('ana@pointage.bj', 'pw');
    expect(result, isA<LoginAuthenticated>());
    expect((result as LoginAuthenticated).tokens.accessToken, 'a');
  });

  test('several companies ask for a choice', () async {
    final result = await repo(_choice).verifyCode('ana@pointage.bj', '123456');
    expect(result, isA<LoginSelectionRequired>());
    final choice = result as LoginSelectionRequired;
    expect(choice.selectionToken, 'sel');
    expect(choice.employments.map((e) => (e.employeeId, e.companyName, e.role.wire)).toList(),
        [('emp1', 'Société A', 'EMPLOYEE'), ('emp2', null, 'HR')]);
  });

  test('selectEmployee posts the selection token and the chosen record', () async {
    final tokens = await repo(_pair).selectEmployee('sel', 'emp2');
    expect(sent.single.url.path, '/auth/select-employee');
    expect(jsonDecode(sent.single.body), {'selectionToken': 'sel', 'employeeId': 'emp2'});
    expect(tokens.refreshToken, 'r');
  });
}
