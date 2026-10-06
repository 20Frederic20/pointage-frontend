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
    ref.watch(sessionProvider); // repart à zéro quand l'utilisateur change
    return const PunchState();
  }

  Future<void> punch() async {
    final employeeNumber = ref.read(sessionProvider);
    if (state.loading || employeeNumber == null) return;
    state = PunchState(last: state.last, loading: true);
    try {
      final entry = await ref.read(punchRepositoryProvider).punch(employeeNumber);
      state = PunchState(last: entry);
    } catch (e) {
      state = PunchState(last: state.last, error: e is ApiException ? e.message : 'Pointage impossible, vérifiez la connexion.');
    }
  }
}

final punchControllerProvider = NotifierProvider<PunchController, PunchState>(PunchController.new);

/// Horloge rafraîchie chaque seconde.
final clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
