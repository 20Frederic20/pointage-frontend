import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../work_time_controller.dart';
import '../work_time_model.dart';

/// Pointages, pour les grands écrans.
class TimeEntriesTable extends StatelessWidget {
  const TimeEntriesTable({super.key, required this.entries});
  final List<TimeEntryRow> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employé')),
                  DataColumn(label: Text('Entreprise')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Date / heure')),
                  DataColumn(label: Text('Entrée/Sortie')),
                  DataColumn(label: Text('Origine')),
                  DataColumn(label: Text('Statut')),
                ],
                rows: [
                  for (final e in entries)
                    DataRow(key: ValueKey(e.id), cells: [
                      DataCell(_TwoLines(e.displayName, e.employeeNumber)),
                      DataCell(Text(e.companyName ?? '—')),
                      DataCell(Text(e.siteName ?? '—')),
                      DataCell(Text(formatDateTime(e.occuredAt))),
                      DataCell(Text(e.isIn ? 'Entrée' : 'Sortie')),
                      DataCell(_TwoLines(entrySourceLabel(e.source), e.assistedByName)),
                      DataCell(StatusChip(status: e.validationStatus)),
                    ]),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TwoLines extends StatelessWidget {
  const _TwoLines(this.first, this.second);
  final String first;
  final String? second;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first),
          if (second case final s?) Text(s, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

/// « Compté », « En attente » ou « Rejeté ».
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'COUNTED' => AppColors.green,
      'REJECTED' => AppColors.red,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(validationStatusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
