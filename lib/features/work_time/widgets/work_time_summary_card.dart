import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../work_time_model.dart';

/// Synthèse d'un employé, pour les petits écrans.
class WorkTimeSummaryCard extends StatelessWidget {
  const WorkTimeSummaryCard({super.key, required this.row, required this.onTap});

  final WorkTimeSummaryRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warnings = [
      if (row.toCheckDays > 0) '${row.toCheckDays} à vérifier',
      if (row.notCalculatedDays > 0) '${row.notCalculatedDays} non calculé(s)',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text('${row.displayName} · ${row.employeeNumber}', overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatDuration(row.workedTotal)} travaillées · ${row.presentDays} présence(s) · ${row.absentDays} absence(s)\n'
          '${row.lateDays} retard(s) (${formatDuration(row.lateTotal)}) · ${row.overtimeDays} j. heures supp.'
          '${warnings.isEmpty ? '' : ' · ${warnings.join(' · ')}'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
