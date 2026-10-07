import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Réponse de /auth/login, /auth/otp/verify et /auth/refresh.
class TokenPair {
  TokenPair({required this.accessToken, required this.refreshToken, required this.expiresIn});

  final String accessToken;
  final String refreshToken;
  final int expiresIn; // secondes (15 min)

  factory TokenPair.fromJson(Map<String, dynamic> j) => TokenPair(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresIn: j['expiresIn'] as int,
      );
}

/// Routes `/auth/*` du backend. `identifier` = matricule ou email : le backend
/// retrouve le compte et envoie toujours le code à l'email du compte.
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Toujours 202, que le compte existe ou non (le backend ne le révèle pas).
  Future<void> requestCode(String identifier) => _api.post('/auth/otp/request', {'identifier': identifier});

  Future<TokenPair> verifyCode(String identifier, String code) async =>
      TokenPair.fromJson(await _api.post('/auth/otp/verify', {'identifier': identifier, 'code': code}));

  Future<TokenPair> loginWithPassword(String identifier, String password) async =>
      TokenPair.fromJson(await _api.post('/auth/login', {'identifier': identifier, 'password': password}));

  /// Rotation : l'ancien jeton est révoqué, la session gagne 36 h.
  Future<TokenPair> refresh(String refreshToken) async =>
      TokenPair.fromJson(await _api.post('/auth/refresh', {'refreshToken': refreshToken}));

  Future<void> logout(String refreshToken) => _api.post('/auth/logout', {'refreshToken': refreshToken});
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
