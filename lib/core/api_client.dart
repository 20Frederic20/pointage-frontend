import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// URL du backend : `flutter run --dart-define=API_URL=http://192.168.1.10:8000`.
/// Par défaut : localhost sur le web, 10.0.2.2 (= le PC hôte) depuis l'émulateur Android.
const _apiUrlOverride = String.fromEnvironment('API_URL');
final apiUrl = _apiUrlOverride.isNotEmpty
    ? _apiUrlOverride
    : (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000');

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await _http
        .post(
          Uri.parse('$apiUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      // DomainErrorSchema -> "message" ; validation FastAPI -> "detail".
      final msg = data is Map ? (data['message'] ?? data['detail']) : null;
      throw ApiException(msg?.toString() ?? 'Erreur serveur (${res.statusCode})');
    }
    return data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiClient(client);
});
