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
  ApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

/// Codes d'erreur du backend (`DomainErrorSchema.code`) traduits pour l'utilisateur.
const _messages = {
  'INVALID_LOGIN_CODE': 'Code incorrect ou expiré.',
  'INVALID_CREDENTIALS': 'Email ou mot de passe incorrect.',
  'INVALID_REFRESH_TOKEN': 'Session expirée, reconnectez-vous.',
  'INVALID_ACCESS_TOKEN': 'Session expirée, reconnectez-vous.',
  'ACCESS_DENIED': "Vous n'avez pas accès à cette action.",
};

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? accessToken}) async {
    final res = await _http
        .post(
          Uri.parse('$apiUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = res.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final code = data is Map ? data['code'] as String? : null;
      final message = _messages[code] ??
          (res.statusCode == 422
              ? 'Vérifiez les informations saisies.'
              : (data is Map ? data['message'] as String? : null) ?? 'Erreur serveur (${res.statusCode})');
      throw ApiException(message, status: res.statusCode, code: code);
    }
    return data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiClient(client);
});
