import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';

ApiClient clientReplying(int status, Object? body, {void Function(http.Request)? onRequest}) =>
    ApiClient(MockClient((req) async {
      onRequest?.call(req);
      return http.Response.bytes(body == null ? [] : utf8.encode(body is String ? body : jsonEncode(body)), status);
    }));

void main() {
  test('get sends the bearer token and the query parameters', () async {
    late http.Request sent;
    final api = clientReplying(200, {'items': [], 'total': 0}, onRequest: (r) => sent = r);
    final data = await api.get('/employees', accessToken: 'tok', query: {'limit': '20', 'offset': '0'});
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(sent.url.path, '/employees');
    expect(sent.url.queryParameters, {'limit': '20', 'offset': '0'});
    expect(data, {'items': [], 'total': 0});
  });

  test('get without query parameters adds no "?"', () async {
    late http.Request sent;
    await clientReplying(200, [], onRequest: (r) => sent = r).get('/directories/dir1/sites');
    expect(sent.url.hasQuery, isFalse);
  });

  test('a known backend code is translated', () async {
    final api = clientReplying(403, {'code': 'TOO_FAR_FROM_WORKPLACE', 'message': 'Too far'});
    await expectLater(
      api.post('/time-entries', {}),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 403)
          .having((e) => e.code, 'code', 'TOO_FAR_FROM_WORKPLACE')
          .having((e) => e.message, 'message', contains('trop loin'))),
    );
  });

  test('422 is reported as invalid input on get and post', () async {
    final api = clientReplying(422, {'detail': []});
    await expectLater(api.get('/users'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Vérifiez les informations saisies.')));
    await expectLater(api.post('/employees', {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Vérifiez les informations saisies.')));
  });

  test('an unknown backend message is replaced by a French one', () async {
    final api = clientReplying(409, {'code': 'SOMETHING_NEW', 'message': 'Stale version'});
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', startsWith('Conflit'))));
  });

  test('a non-JSON error body still gives a readable error', () async {
    final api = clientReplying(502, '<html>Bad gateway</html>');
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Erreur serveur (502)')));
  });

  test('an empty success body decodes to an empty map', () async {
    expect(await clientReplying(202, null).post('/auth/otp/request', {'identifier': 'x'}), isEmpty);
  });

  test('postMultipart sends the file part, the fields and the bearer token', () async {
    late http.BaseRequest sent;
    late String body;
    final api = ApiClient(MockClient((req) async {
      sent = req;
      body = req.body;
      return http.Response('{"id":"e1"}', 201);
    }));
    final data = await api.postMultipart('/assisted-punches', {'employee_number': 'EMP0000002'},
        fileField: 'photo', bytes: [1, 2, 3], filename: 'selfie.jpg', contentType: 'image/jpeg', accessToken: 'tok');
    expect(data, {'id': 'e1'});
    expect(sent.method, 'POST');
    expect(sent.url.path, '/assisted-punches');
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(sent.headers['Content-Type'], startsWith('multipart/form-data'));
    expect(body, contains('name="employee_number"'));
    expect(body, contains('EMP0000002'));
    expect(body, contains('name="photo"'));
    expect(body, contains('filename="selfie.jpg"'));
    expect(body, contains('image/jpeg'));
  });

  test('postMultipart maps INVALID_PHOTO to its message', () async {
    final api = clientReplying(422, {'code': 'INVALID_PHOTO', 'message': 'bad'});
    await expectLater(
      api.postMultipart('/x', {}, fileField: 'photo', bytes: [1], filename: 'a.jpg', contentType: 'image/jpeg'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'INVALID_PHOTO')
          .having((e) => e.message, 'message', 'La photo est invalide (JPEG ou PNG, 5 Mo maximum).')),
    );
  });

  test('getBytes returns the raw bytes and shares the error handling', () async {
    late http.Request sent;
    final ok = ApiClient(MockClient((req) async {
      sent = req;
      return http.Response.bytes([9, 8, 7], 200);
    }));
    expect(await ok.getBytes('/photo', accessToken: 'tok'), [9, 8, 7]);
    expect(sent.headers['Authorization'], 'Bearer tok');
    await expectLater(
      clientReplying(404, {'code': 'NOT_FOUND'}).getBytes('/photo'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  test('new assisted-punch codes and the 500 m distance are translated', () async {
    const expected = {
      'SELF_ASSISTED_PUNCH': 'Saisissez le matricule du collègue qui pointe, pas le vôtre.',
      'SELF_MANAGER_PUNCH': 'Utilisez votre propre pointage pour vous-même.',
      'ANOMALY_ALREADY_DECIDED': 'Cette anomalie a déjà été traitée.',
      'DECISION_COMMENT_REQUIRED': 'Un commentaire est obligatoire pour rejeter.',
      'SELF_DECISION': 'Vous ne pouvez pas traiter une anomalie qui vous concerne.',
      'TOO_FAR_FROM_WORKPLACE': 'Vous êtes trop loin de votre lieu de travail pour pointer (500 m maximum).',
    };
    for (final e in expected.entries) {
      await expectLater(clientReplying(409, {'code': e.key}).get('/x'),
          throwsA(isA<ApiException>().having((x) => x.message, 'message', e.value)));
    }
  });

  test('patch sends JSON with the bearer token and maps error codes', () async {
    late http.Request sent;
    final data = await clientReplying(200, {'id': 'emp1'}, onRequest: (r) => sent = r)
        .patch('/employees/emp1', {'phone': '0197000000'}, accessToken: 'tok');
    expect((sent.method, sent.url.path, sent.headers['Authorization']), ('PATCH', '/employees/emp1', 'Bearer tok'));
    expect(jsonDecode(sent.body), {'phone': '0197000000'});
    expect(data, {'id': 'emp1'});
    await expectLater(clientReplying(403, {'code': 'ROLE_CEILING'}).patch('/employees/emp1', {}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Vous ne pouvez pas attribuer ou modifier un rôle supérieur au vôtre.')));
  });

  test('the employee-action error codes are translated', () async {
    const expected = {
      'SELF_DEACTIVATION': 'Vous ne pouvez pas vous désactiver vous-même.',
      'EMPLOYEE_INACTIVE': 'Cet employé est désactivé.',
      'EMPLOYEE_ALREADY_INACTIVE': 'Cet employé est déjà désactivé.',
      'EMPLOYEE_ALREADY_ACTIVE': 'Cet employé est déjà actif.',
      'ALREADY_ACTIVE_IN_COMPANY': 'Cette personne a déjà une fiche active dans cette entreprise.',
      'ASSIGNMENT_IN_PAST': 'La date de début ne peut pas être dans le passé.',
      'FUTURE_ASSIGNMENT_EXISTS': "Une affectation future existe déjà : terminez-la d'abord.",
      'DIRECTORY_OUTSIDE_COMPANY': "Ce service n'appartient pas à l'entreprise de l'employé.",
      'OVERLAPPING_EMPLOYEE_ASSIGNMENT': 'Cette affectation chevauche une autre affectation.',
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      await expectLater(clientReplying(409, {'code': key}).post('/x', {}),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', value)), reason: key);
    }
  });
}
