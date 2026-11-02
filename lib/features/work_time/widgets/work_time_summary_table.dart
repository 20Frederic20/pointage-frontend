import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../work_time_model.dart';

/// Synthèse par employé (mêmes colonnes que l'export), pour les grands écrans.
class WorkTimeSummaryTable extends StatelessWidget {
  const WorkTimeSummaryTable({super.key, required this.rows, required this.onTap});

  final List<WorkTimeSummaryRow> rows;
  final ValueChanged<WorkTimeSummaryRow> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Matricule')),
                  DataColumn(label: Text('Nom')),
                  DataColumn(label: Text('Entreprise')),
                  DataColumn(label: Text('Présences'), numeric: true),
                  DataColumn(label: Text('Absences'), numeric: true),
                  DataColumn(label: Text('Retards'), numeric: true),
                  DataColumn(label: Text('Retard total'), numeric: true),
                  DataColumn(label: Text('Heures travaillées'), numeric: true),
                  DataColumn(label: Text('Jours avec heures supp.'), numeric: true),
                  DataColumn(label: Text('Jours à vérifier'), numeric: true),
                  DataColumn(label: Text('Jours non calculés'), numeric: true),
                ],
                rows: [
                  for (final s in rows)
                    DataRow(key: ValueKey(s.employeeId), onSelectChanged: (_) => onTap(s), cells: [
                      DataCell(Text(s.employeeNumber)),
                      DataCell(Text(s.displayName)),
                      DataCell(Text(s.companyName ?? '—')),
                      DataCell(Text('${s.presentDays}')),
                      DataCell(Text('${s.absentDays}')),
                      DataCell(Text('${s.lateDays}')),
                      DataCell(Text(formatDuration(s.lateTotal))),
                      DataCell(Text(formatDuration(s.workedTotal))),
                      DataCell(Text('${s.overtimeDays}')),
                      DataCell(_Count(s.toCheckDays)),
                      DataCell(_Count(s.notCalculatedDays)),
                    ]),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Un compte à surveiller : mis en évidence quand il n'est pas nul.
class _Count extends StatelessWidget {
  const _Count(this.value);
  final int value;

  @override
  Widget build(BuildContext context) => Text('$value',
      style: value > 0 ? const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold) : null);
}
