import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/user/user_model.dart';
import 'package:pointage/features/user/user_repository.dart';

Map<String, dynamic> userJson({String? first, String? last}) => {
      'id': 'usr1', 'email': 'ana@pointage.bj', 'role': 'EMPLOYEE', 'isActive': true,
      'firstName': first, 'lastName': last, 'avatarUrl': null, 'lastActiveAt': null, 'createdAt': null, 'updatedAt': null,
    };

void main() {
  test('displayName shows the name and the email', () {
    expect(AppUser.fromJson(userJson(first: 'Ana', last: 'Dossou')).displayName, 'Ana Dossou — ana@pointage.bj');
  });

  test('displayName falls back to the email when there is no name', () {
    expect(AppUser.fromJson(userJson(first: ' ', last: null)).displayName, 'ana@pointage.bj');
  });

  test('list reads a page of users', () async {
    late http.Request sent;
    final repo = UserRepository(ApiClient(MockClient((req) async {
      sent = req;
      return http.Response(jsonEncode({'items': [userJson()], 'total': 1}), 200);
    })));
    final page = await repo.list('tok');
    expect(sent.url.queryParameters, {'limit': '100', 'offset': '0'});
    expect(page.items.single.email, 'ana@pointage.bj');
  });
}
