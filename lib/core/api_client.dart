import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

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
  'TOO_FAR_FROM_WORKPLACE': 'Vous êtes trop loin de votre lieu de travail pour pointer (500 m maximum).',
  'EMPLOYEE_NOT_ASSIGNED': "Vous n'avez pas d'affectation active aujourd'hui. Contactez votre responsable.",
  'EMPLOYEE_WITH_THIS_NUMBER_ALREADY_EXISTS': 'Ce matricule est déjà utilisé.',
  'SITE_NOT_IN_DIRECTORY': "Ce site n'appartient pas à l'annuaire choisi.",
  'DIRECTORY_HAS_NO_SITE': "Cet annuaire n'a aucun site : créez-en un d'abord.",
  'SITE_INACTIVE': 'Ce site est désactivé.',
  'PUNCH_ALREADY_EXISTS': 'Ce pointage a déjà été enregistré.',
  'INVALID_ENTITY_ID': 'Identifiant invalide.',
  'SELF_ASSISTED_PUNCH': 'Saisissez le matricule du collègue qui pointe, pas le vôtre.',
  'INVALID_PHOTO': 'La photo est invalide (JPEG ou PNG, 5 Mo maximum).',
  'SELF_MANAGER_PUNCH': 'Utilisez votre propre pointage pour vous-même.',
  'ANOMALY_ALREADY_DECIDED': 'Cette anomalie a déjà été traitée.',
  'DECISION_COMMENT_REQUIRED': 'Un commentaire est obligatoire pour rejeter.',
  'DECISION_COMMENT_TOO_LONG': 'Le commentaire ne doit pas dépasser 512 caractères.',
  'SELF_DECISION': 'Vous ne pouvez pas traiter une anomalie qui vous concerne.',
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

  /// Envoi `multipart/form-data` (champs texte + un fichier), par exemple un pointage assisté avec selfie.
  Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, String> fields, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? accessToken,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(fileField, bytes,
          filename: filename, contentType: MediaType.parse(contentType)));
    if (accessToken != null) req.headers['Authorization'] = 'Bearer $accessToken';
    final res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    return _handle(res) as Map<String, dynamic>;
  }

  /// Corps brut d'une réponse (image, par exemple) ; mêmes erreurs que [get].
  Future<Uint8List> getBytes(String path, {String? accessToken}) async {
    final res = await _http.get(_uri(path), headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'}).timeout(_timeout);
    if (res.statusCode < 400) return res.bodyBytes;
    _handle(res); // lève l'erreur traduite
    throw ApiException(_fallback(res.statusCode), status: res.statusCode);
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
