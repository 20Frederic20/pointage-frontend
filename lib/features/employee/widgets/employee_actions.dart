import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/role.dart';
import '../../../core/theme.dart';
import '../../auth/session_provider.dart';
import '../employee_actions_controller.dart';
import '../employee_model.dart';
import 'assign_employee_dialog.dart';
import 'edit_employee_dialog.dart';
import 'punch_for_employee_button.dart';

/// Affiche le résultat d'une action en bas de l'écran.
void showActionOutcome(ScaffoldMessengerState messenger, ActionOutcome? outcome) {
  if (outcome == null) return;
  messenger.showSnackBar(SnackBar(
    backgroundColor: outcome.ok ? AppColors.green : AppColors.red,
    content: Text(outcome.message),
  ));
}

/// Les boutons de la fiche : faire pointer, modifier, désactiver ou réactiver, affecter à un site.
class EmployeeActions extends ConsumerWidget {
  const EmployeeActions({super.key, required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(employeeActionsControllerProvider(employee.id));
    final actions = ref.read(employeeActionsControllerProvider(employee.id).notifier);
    final session = ref.watch(sessionProvider).value;

    Future<void> edit() async {
      final messenger = ScaffoldMessenger.of(context);
      final change = await showDialog<EmployeeEdit>(
        context: context,
        builder: (_) => EditEmployeeDialog(
          employee: employee,
          maxRole: session?.role ?? Role.employee,
          ownRecord: session?.userId == employee.userId,
        ),
      );
      if (change == null) return;
      if ([change.firstName, change.lastName, change.phone, change.role].every((v) => v == null)) return;
      showActionOutcome(
        messenger,
        await actions.run('Employé modifié.', (repo, token) => repo.update(token, employee.id,
            firstName: change.firstName, lastName: change.lastName, phone: change.phone, role: change.role)),
      );
    }

    Future<void> toggleActive() async {
      final messenger = ScaffoldMessenger.of(context);
      final deactivating = employee.isActive;
      final verb = deactivating ? 'Désactiver' : 'Réactiver';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(
          question: deactivating
              ? 'Désactiver ${employee.displayName} ? Il ne pourra plus pointer.'
              : 'Réactiver ${employee.displayName} ?',
          confirm: verb,
        ),
      );
      if (confirmed != true) return;
      showActionOutcome(
        messenger,
        await actions.run(
          deactivating ? 'Employé désactivé.' : 'Employé réactivé.',
          (repo, token) => deactivating ? repo.deactivate(token, employee.id) : repo.activate(token, employee.id),
        ),
      );
    }

    Future<void> assign() async {
      final messenger = ScaffoldMessenger.of(context);
      final choice = await showDialog<AssignmentChoice>(
        context: context,
        builder: (_) => AssignEmployeeDialog(employee: employee),
      );
      if (choice == null) return;
      showActionOutcome(
        messenger,
        await actions.run('Affectation enregistrée.', (repo, token) => repo.assign(token,
            employeeId: employee.id,
            directoryId: choice.directoryId,
            siteId: choice.siteId,
            startDate: choice.startDate,
            endDate: choice.endDate)),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (employee.isActive) PunchForEmployeeButton(employee: employee, labeled: true),
      OutlinedButton.icon(onPressed: busy ? null : edit, icon: const Icon(Icons.edit_outlined), label: const Text('Modifier')),
      OutlinedButton.icon(
        onPressed: busy ? null : toggleActive,
        icon: Icon(employee.isActive ? Icons.person_off_outlined : Icons.person_outline),
        label: Text(employee.isActive ? 'Désactiver' : 'Réactiver'),
      ),
      if (employee.isActive)
        OutlinedButton.icon(
          onPressed: busy ? null : assign,
          icon: const Icon(Icons.place_outlined),
          label: const Text('Affecter à un site'),
        ),
    ]);
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.question, required this.confirm});
  final String question;
  final String confirm;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _done = false;

  /// Un double appui ne ferme qu'une fois (un second pop fermerait la page dessous).
  void _close(bool value) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Text(widget.question),
        actions: [
          TextButton(onPressed: () => _close(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => _close(true), child: Text(widget.confirm)),
        ],
      );
}
