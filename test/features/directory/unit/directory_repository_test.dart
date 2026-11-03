import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';

const _dir = {'id': 'dir1', 'name': 'Société A', 'code': 'SA', 'parentDirectoryId': null, 'active': false};
const _site = {
  'id': 'sit1', 'directoryId': 'dir1', 'name': 'Siège', 'kind': 'PRINCIPAL', 'active': true,
  'location': {'latitude': 6.36, 'longitude': 2.41}, 'address': 'Rue 1',
};

void main() {
  late List<http.Request> sent;
  DirectoryRepository repo(Object Function(http.Request) respond, {int status = 200}) {
    sent = [];
    return DirectoryRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(utf8.encode(jsonEncode(respond(req))), status);
    })));
  }

  Map<String, dynamic> body(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  test('models read active, the position, the address and the principal flag', () async {
    final r = repo((req) => req.url.path.endsWith('/sites') ? [_site] : {'items': [_dir], 'total': 1});
    final d = (await r.list('tok')).items.single;
    final s = (await r.sites('tok', 'dir1')).single;
    expect(d.active, isFalse);
    expect((s.directoryId, s.latitude, s.longitude, s.address, s.isPrincipal, s.active),
        ('dir1', 6.36, 2.41, 'Rue 1', true, true));
  });

  test('all() pages until the total', () async {
    final r = repo((req) {
      final offset = int.parse(req.url.queryParameters['offset']!);
      return {
        'items': [for (var i = offset; i < (offset + 200).clamp(0, 250); i++) {..._dir, 'id': 'd$i'}],
        'total': 250,
      };
    });
    expect((await r.all('tok')).length, 250);
    expect(sent.map((r) => r.url.queryParameters['offset']), ['0', '200']);
    expect(sent.first.url.queryParameters['limit'], '200');
  });

  test('directory actions: create, update, deactivate, activate', () async {
    final r = repo((req) => _dir);
    await r.create('tok', name: 'Agence', code: 'AG', parentDirectoryId: 'dir1');
    await r.update('tok', 'dir1', name: 'Société Alpha', code: 'SAL');
    await r.setActive('tok', 'dir1', false);
    await r.setActive('tok', 'dir1', true);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'POST /directories',
      'PATCH /directories/dir1',
      'POST /directories/dir1/deactivate',
      'POST /directories/dir1/activate',
    ]);
    expect(body(sent[0]), {'name': 'Agence', 'code': 'AG', 'parent_directory_id': 'dir1'});
    expect(body(sent[1]), {'name': 'Société Alpha', 'code': 'SAL'});
  });

  test('site actions: create, update, deactivate, make principal', () async {
    final r = repo((req) => _site);
    await r.createSite('tok', directoryId: 'dir1', name: 'Annexe', latitude: 6.4, longitude: 2.5, address: null);
    await r.updateSite('tok', 'sit1', name: 'Annexe 2', address: 'Rue 2', latitude: 6.41, longitude: 2.51);
    await r.setSiteActive('tok', 'sit1', false);
    await r.makePrincipal('tok', 'sit1');
    expect(sent.map((r) => '${r.method} ${r.url.path}'),
        ['POST /sites', 'PATCH /sites/sit1', 'POST /sites/sit1/deactivate', 'POST /sites/sit1/make-principal']);
    expect(body(sent[0]), {'directory_id': 'dir1', 'name': 'Annexe', 'latitude': 6.4, 'longitude': 2.5});
    expect(body(sent[1]), {'name': 'Annexe 2', 'address': 'Rue 2', 'latitude': 6.41, 'longitude': 2.51});
  });

  test('new backend codes are translated', () async {
    for (final (code, message) in [
      ('DIRECTORY_INACTIVE', 'Cet annuaire est désactivé.'),
      ('DIRECTORY_ALREADY_EXISTS', "Ce code d'annuaire est déjà utilisé."),
      ('PRINCIPAL_SITE_CANNOT_BE_DEACTIVATED',
          'Le site principal ne peut pas être désactivé : rendez d\'abord un autre site principal.'),
    ]) {
      await expectLater(repo((_) => {'code': code}, status: 409).setSiteActive('tok', 'sit1', false),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', message)));
    }
  });
}
