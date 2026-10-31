import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';

void main() {
  final responses = <String, Object>{
    '/directories': {
      'items': [{'id': 'dir1', 'name': 'Direction générale', 'code': 'DG', 'parentDirectoryId': null}],
      'total': 1,
    },
    '/directories/dir1/sites': [
      {
        'id': 'sit1', 'directoryId': 'dir1', 'name': 'Siège Cotonou', 'kind': 'PRINCIPAL', 'active': true,
        'location': {'latitude': 6.36, 'longitude': 2.41}, 'address': null,
      },
    ],
  };
  final repo = DirectoryRepository(ApiClient(MockClient(
    (req) async => http.Response.bytes(utf8.encode(jsonEncode(responses[req.url.path])), 200),
  )));

  test('list reads a page of directories', () async {
    final page = await repo.list('tok');
    expect(page.items.single.name, 'Direction générale');
    expect(page.items.single.code, 'DG');
  });

  test('sites reads the sites of one directory', () async {
    final sites = await repo.sites('tok', 'dir1');
    expect(sites.single.id, 'sit1');
    expect(sites.single.name, 'Siège Cotonou');
  });
}
