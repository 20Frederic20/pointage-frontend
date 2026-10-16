import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// URL du backend. Par défaut `localhost:8000`, valable partout :
/// - web : le navigateur tourne sur le PC ;
/// - téléphone USB ou émulateur : `adb reverse tcp:8000 tcp:8000` relie le port du téléphone au PC.
/// Sans câble (Wi-Fi) : `flutter run --dart-define=API_URL=http://<ip-du-pc>:8000`.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.1.6.185:8000');

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
  'ROLE_PERMISSION_DENIED': "Vous n'avez pas accès à cette action.",
  'TOO_FAR_FROM_WORKPLACE': 'Vous êtes trop loin de votre lieu de travail pour pointer (100 m maximum).',
  'EMPLOYEE_NOT_ASSIGNED': "Vous n'avez pas d'affectation active aujourd'hui. Contactez votre responsable.",
  'EMPLOYEE_WITH_THIS_NUMBER_ALREADY_EXISTS': 'Ce matricule est déjà utilisé.',
  'SITE_NOT_IN_DIRECTORY': "Ce site n'appartient pas à l'annuaire choisi.",
  'DIRECTORY_HAS_NO_SITE': "Cet annuaire n'a aucun site : créez-en un d'abord.",
  'SITE_INACTIVE': 'Ce site est désactivé.',
  'PUNCH_ALREADY_EXISTS': 'Ce pointage a déjà été enregistré.',
  'INVALID_ENTITY_ID': 'Identifiant invalide.',
  'NOT_FOUND': 'Élément introuvable.',
  'CONFLICT': 'Conflit : cet élément existe déjà ou a été modifié entre-temps.',
};

/// Message par statut HTTP quand le code d'erreur n'est pas connu :
/// les messages bruts du backend (en anglais) ne sont jamais montrés.
String _fallback(int status) => switch (status) {
      401 => 'Session expirée, reconnectez-vous.',
      403 => "Vous n'avez pas accès à cette action.",
      404 => 'Élément introuvable.',
      409 => 'Conflit : cet élément existe déjà ou a été modifié entre-temps.',
      422 => 'Vérifiez les informations saisies.',
      >= 500 => 'Erreur serveur ($status)',
      _ => 'Requête refusée ($status)',
    };

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? accessToken}) async {
    final res = await _http
        .post(_uri(path), headers: _headers(accessToken), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res) as Map<String, dynamic>;
  }

  Future<dynamic> get(String path, {String? accessToken, Map<String, String>? query}) async {
    final res = await _http.get(_uri(path, query), headers: _headers(accessToken)).timeout(_timeout);
    return _handle(res);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$apiUrl$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(String? accessToken) => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  /// Corps JSON décodé, ou [ApiException] avec un message lisible.
  dynamic _handle(http.Response res) {
    Object? data;
    try {
      data = res.bodyBytes.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      data = null; // page d'erreur HTML d'un proxy, par exemple
    }
    if (res.statusCode < 400 && data != null) return data;
    final code = data is Map ? data['code'] as String? : null;
    throw ApiException(_messages[code] ?? _fallback(res.statusCode), status: res.statusCode, code: code);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiClient(client);
});
