import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import 'auth_repository.dart';

class Session {
  Session({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.identifier,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  /// Matricule ou email saisi à la connexion, affiché en haut de l'écran.
  final String identifier;

  factory Session.from(TokenPair t, String identifier) => Session(
        accessToken: t.accessToken,
        refreshToken: t.refreshToken,
        accessExpiresAt: DateTime.now().add(Duration(seconds: t.expiresIn)),
        identifier: identifier,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessExpiresAt': accessExpiresAt.toIso8601String(),
        'identifier': identifier,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        accessExpiresAt: DateTime.parse(j['accessExpiresAt'] as String),
        identifier: j['identifier'] as String,
      );
}

/// Session courante (null = déconnecté), gardée dans le stockage sécurisé du téléphone.
///
/// Le backend ferme la session après 36 h sans activité (30 jours au plus) :
/// au démarrage on la rafraîchit, ce qui repousse l'échéance de 36 h.
class SessionNotifier extends AsyncNotifier<Session?> {
  static const _key = 'session';
  static const _storage = FlutterSecureStorage();

  /// Un seul rafraîchissement à la fois : présenter deux fois le même jeton
  /// ferait révoquer toute la session par le backend (détection de vol).
  Future<Session?>? _refreshing;

  @override
  Future<Session?> build() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return _refresh(Session.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }

  Future<void> signIn(TokenPair tokens, String identifier) async {
    final session = Session.from(tokens, identifier);
    await _save(session);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    final session = state.value;
    state = const AsyncData(null);
    await _storage.delete(key: _key);
    if (session != null) {
      try {
        await ref.read(authRepositoryProvider).logout(session.refreshToken);
      } catch (_) {
        // Hors ligne : la session expirera seule côté serveur.
      }
    }
  }

  /// Jeton d'accès valide, rafraîchi si besoin. null = session terminée.
  Future<String?> accessToken() async {
    final session = state.value;
    if (session == null) return null;
    if (DateTime.now().isBefore(session.accessExpiresAt.subtract(const Duration(seconds: 30)))) {
      return session.accessToken;
    }
    final refreshed = await (_refreshing ??= _refresh(session).whenComplete(() => _refreshing = null));
    state = AsyncData(refreshed);
    return refreshed?.accessToken;
  }

  Future<Session?> _refresh(Session session) async {
    try {
      final tokens = await ref.read(authRepositoryProvider).refresh(session.refreshToken);
      final next = Session.from(tokens, session.identifier);
      await _save(next);
      return next;
    } on ApiException catch (e) {
      if (e.status == 401) {
        await _storage.delete(key: _key);
        return null;
      }
      return session;
    } catch (_) {
      return session; // hors ligne : on garde la session, le serveur tranchera
    }
  }

  Future<void> _save(Session s) => _storage.write(key: _key, value: jsonEncode(s.toJson()));
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

/// Jeton valide pour un appel API ; lève une [ApiException] 401 quand la session est terminée
/// (main.dart renvoie alors vers la connexion).
Future<String> requireAccessToken(Ref ref) async {
  final token = await ref.read(sessionProvider.notifier).accessToken();
  if (token == null) throw ApiException('Session expirée, reconnectez-vous.', status: 401);
  return token;
}
