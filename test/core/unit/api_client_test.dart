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
}
