import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import 'employee_badges.dart';
import 'assignment_history.dart';
import 'employee_actions.dart';

/// Contenu de la fiche, partagé par le panneau (grand écran) et la page (petit écran).
class EmployeeDetailView extends ConsumerWidget {
  const EmployeeDetailView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(employeeDetailProvider(id))) {
        AsyncData(:final value) => _Details(employee: value),
        AsyncError(:final error) =>
          ErrorState(message: employeeErrorMessage(error), onRetry: () => ref.invalidate(employeeDetailProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      };
}

class _Details extends StatelessWidget {
  const _Details({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(employee.displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        if (employee.displayName != employee.employeeNumber) Text(employee.employeeNumber),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          RoleBadge(role: employee.role),
          StatusPill(isActive: employee.isActive),
        ]),
        const SizedBox(height: 12),
        EmployeeActions(employee: employee),
        const Divider(height: 32),
        _Field(label: 'Entreprise', value: employee.companyName ?? '—'),
        _Field(label: 'Site actuel', value: employee.currentSiteName ?? '—'),
        _Field(label: 'Téléphone', value: employee.phone ?? '—'),
        _Field(label: 'Créé le', value: formatDate(employee.createdAt)),
        _Field(label: 'Modifié le', value: formatDate(employee.updatedAt)),
        _Field(label: 'Identifiant utilisateur', value: employee.userId),
        const Divider(height: 32),
        AssignmentHistory(employeeId: employee.id),
      ]);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 2),
        SelectableText(value, style: text.bodyLarge),
      ]),
    );
  }
}

/// Fiche affichée à droite de la liste sur grand écran.
class EmployeeDetailPanel extends StatelessWidget {
  const EmployeeDetailPanel({super.key, required this.id, required this.onClose});
  final String id;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          ListTile(
            title: Text("Détail de l'employé", style: Theme.of(context).textTheme.titleMedium),
            trailing: IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onClose),
          ),
          const Divider(height: 1),
          Expanded(child: EmployeeDetailView(key: ValueKey(id), id: id)),
        ]),
      );
}
