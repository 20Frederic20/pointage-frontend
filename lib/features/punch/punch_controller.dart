import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'punch_repository.dart';

class PunchState {
  const PunchState({this.last, this.loading = false, this.error});

  /// Dernier pointage de la session (null = pas encore pointé).
  final TimeEntry? last;
  final bool loading;
  final String? error;
}

// ponytail: pas de GET du dernier pointage côté backend, l'état repart à zéro au redémarrage.
class PunchController extends Notifier<PunchState> {
  @override
  PunchState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier)); // repart à zéro quand l'utilisateur change
    return const PunchState();
  }

  Future<void> punch() async {
    if (state.loading || ref.read(sessionProvider).value == null) return;
    state = PunchState(last: state.last, loading: true);
    try {
      final token = await ref.read(sessionProvider.notifier).accessToken();
      if (token == null) { // session expirée : main.dart renvoie vers la connexion
        state = PunchState(last: state.last);
        return;
      }
      final entry = await ref.read(punchRepositoryProvider).punch(token);
      state = PunchState(last: entry);
    } catch (e) {
      state = PunchState(last: state.last, error: _message(e));
    }
  }
}

String _message(Object e) => switch (e) {
      ApiException(code: 'NOT_FOUND') => "Aucune fiche employé n'est liée à ce compte.",
      ApiException(:final message) => message,
      _ => 'Pointage impossible, vérifiez la connexion.',
    };

final punchControllerProvider = NotifierProvider<PunchController, PunchState>(PunchController.new);

/// Horloge rafraîchie chaque seconde.
final clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
