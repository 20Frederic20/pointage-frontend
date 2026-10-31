import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/role.dart';

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

/// Une fiche employé du compte : l'entreprise et le rôle qu'on y a.
class Employment {
  Employment({required this.employeeId, required this.companyName, required this.role});

  final String employeeId;
  final String? companyName;
  final Role role;

  factory Employment.fromJson(Map<String, dynamic> j) => Employment(
        employeeId: j['employeeId'] as String,
        companyName: j['companyName'] as String?,
        role: Role.fromWire(j['role'] as String),
      );
}

/// Résultat d'une connexion : les jetons, ou le choix de l'entreprise (fiches actives dans plusieurs).
sealed class LoginResult {
  const LoginResult();

  factory LoginResult.fromJson(Map<String, dynamic> j) => j['status'] == 'selection_required'
      ? LoginSelectionRequired(
          j['selectionToken'] as String,
          [for (final e in j['employments'] as List) Employment.fromJson(e as Map<String, dynamic>)],
        )
      : LoginAuthenticated(TokenPair.fromJson(j));
}

class LoginAuthenticated extends LoginResult {
  const LoginAuthenticated(this.tokens);
  final TokenPair tokens;
}

class LoginSelectionRequired extends LoginResult {
  const LoginSelectionRequired(this.selectionToken, this.employments);

  /// Valable 5 minutes : à renvoyer avec la fiche choisie.
  final String selectionToken;
  final List<Employment> employments;
}

/// Routes `/auth/*` du backend. `identifier` = matricule ou email : le backend
/// retrouve le compte et envoie toujours le code à l'email du compte.
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Toujours 202, que le compte existe ou non (le backend ne le révèle pas).
  Future<void> requestCode(String identifier) => _api.post('/auth/otp/request', {'identifier': identifier});

  Future<LoginResult> verifyCode(String identifier, String code) async =>
      LoginResult.fromJson(await _api.post('/auth/otp/verify', {'identifier': identifier, 'code': code}));

  Future<LoginResult> loginWithPassword(String identifier, String password) async =>
      LoginResult.fromJson(await _api.post('/auth/login', {'identifier': identifier, 'password': password}));

  /// Après [LoginSelectionRequired] : les jetons de la fiche choisie.
  Future<TokenPair> selectEmployee(String selectionToken, String employeeId) async => TokenPair.fromJson(
      await _api.post('/auth/select-employee', {'selectionToken': selectionToken, 'employeeId': employeeId}));

  /// Rotation : l'ancien jeton est révoqué, la session gagne 36 h.
  Future<TokenPair> refresh(String refreshToken) async =>
      TokenPair.fromJson(await _api.post('/auth/refresh', {'refreshToken': refreshToken}));

  Future<void> logout(String refreshToken) => _api.post('/auth/logout', {'refreshToken': refreshToken});
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
