import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// URL du backend. Par défaut `localhost:8000`, valable partout :
/// - web : le navigateur tourne sur le PC ;
/// - téléphone USB ou émulateur : `adb reverse tcp:8000 tcp:8000` relie le port du téléphone au PC.
/// Sans câble (Wi-Fi) : `flutter run --dart-define=API_URL=http://<ip-du-pc>:8000`.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

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
  'INVALID_CREDENTIALS': 'Identifiant ou mot de passe incorrect.',
  'INVALID_REFRESH_TOKEN': 'Session expirée, reconnectez-vous.',
  'INVALID_ACCESS_TOKEN': 'Session expirée, reconnectez-vous.',
  'ACCESS_DENIED': "Vous n'avez pas accès à cette action.",
  'TOO_FAR_FROM_WORKPLACE': 'Vous êtes trop loin de votre lieu de travail pour pointer (100 m maximum).',
  'EMPLOYEE_NOT_ASSIGNED': "Vous n'avez pas d'affectation active aujourd'hui. Contactez votre responsable.",
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
