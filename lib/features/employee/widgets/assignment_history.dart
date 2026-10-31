import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../assignment_model.dart';
import '../employee_actions_controller.dart';
import 'employee_actions.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Les affectations de l'employé, la plus récente d'abord ; « Terminer » sur celle en cours ou à venir.
class AssignmentHistory extends ConsumerWidget {
  const AssignmentHistory({super.key, required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(employeeActionsControllerProvider(employeeId));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Affectations', style: text.titleMedium),
      const SizedBox(height: 8),
      switch (ref.watch(employeeAssignmentsProvider(employeeId))) {
        AsyncData(value: final list) when list.isEmpty => const Text('Aucune affectation.'),
        AsyncData(value: final list) => Column(children: [
            for (final a in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(a.siteName ?? a.siteId),
                subtitle: Text('${a.directoryName ?? a.directoryId} · du ${formatDate(a.startDate)}'
                    '${a.endDate == null ? '' : ' au ${formatDate(a.endDate)}'}'),
                trailing: _open(a) ? TextButton(onPressed: busy ? null : () => _end(context, ref, a), child: const Text('Terminer')) : null,
              ),
          ]),
        AsyncError() => const Text('Affectations indisponibles.'),
        _ => const LinearProgressIndicator(),
      },
    ]);
  }

  /// En cours ou à venir : sans fin, ou se terminant aujourd'hui ou plus tard.
  bool _open(Assignment a) => a.endDate == null || !a.endDate!.isBefore(_today());

  Future<void> _end(BuildContext context, WidgetRef ref, Assignment a) async {
    final messenger = ScaffoldMessenger.of(context);
    final first = a.startDate.isAfter(_today()) ? a.startDate : _today();
    final day = await showDatePicker(
      context: context,
      helpText: "Dernier jour de l'affectation",
      initialDate: first,
      firstDate: first,
      lastDate: DateTime(_today().year + 5),
    );
    if (day == null) return;
    showActionOutcome(
      messenger,
      await ref
          .read(employeeActionsControllerProvider(employeeId).notifier)
          .run('Affectation terminée.', (repo, token) => repo.endAssignment(token, a.id, day)),
    );
  }
}
