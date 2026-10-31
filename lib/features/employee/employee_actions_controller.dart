import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'assignment_model.dart';
import 'employee_controller.dart';
import 'employee_repository.dart';

/// Les affectations d'un employé, la plus récente d'abord.
final employeeAssignmentsProvider = FutureProvider.autoDispose.family<List<Assignment>, String>(
  (ref, employeeId) async =>
      ref.read(employeeRepositoryProvider).assignments(await requireAccessToken(ref), employeeId),
  retry: (_, _) => null,
);

/// Résultat d'une action, à afficher en bas de l'écran.
typedef ActionOutcome = ({String message, bool ok});

/// Les actions sur une fiche (modifier, désactiver, réactiver, affecter, terminer une affectation).
/// Une seule à la fois : un second appel pendant qu'une action tourne est ignoré.
class EmployeeActionsController extends Notifier<bool> {
  EmployeeActionsController(this.employeeId);
  final String employeeId;

  @override
  bool build() => false; // en cours ?

  /// null quand une action tourne déjà ; sinon le message de succès ou d'erreur.
  Future<ActionOutcome?> run(String success, Future<void> Function(EmployeeRepository repo, String token) call) async {
    if (state) return null;
    state = true;
    // Lus avant tout await : la fiche peut être fermée pendant la requête.
    final repo = ref.read(employeeRepositoryProvider);
    final list = ref.read(employeeControllerProvider.notifier);
    try {
      await call(repo, await requireAccessToken(ref));
      ref.invalidate(employeeDetailProvider(employeeId));
      ref.invalidate(employeeAssignmentsProvider(employeeId));
      await list.refresh();
      return (message: success, ok: true);
    } catch (e) {
      return (message: e is ApiException ? e.message : 'Connexion au serveur impossible, réessayez.', ok: false);
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final employeeActionsControllerProvider =
    NotifierProvider.autoDispose.family<EmployeeActionsController, bool, String>(EmployeeActionsController.new);
