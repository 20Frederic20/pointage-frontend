import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../anomaly_model.dart';

/// Tableau pour les écrans moyens et grands.
class AnomalyTable extends StatelessWidget {
  const AnomalyTable({super.key, required this.anomalies, required this.onTap, this.selectedId});

  final List<Anomaly> anomalies;
  final ValueChanged<Anomaly> onTap;
  final String? selectedId;

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
                  DataColumn(label: Text('Employé')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Pointé depuis le téléphone de')),
                  DataColumn(label: Text('Date / heure')),
                  DataColumn(label: Text('Entrée/Sortie')),
                  DataColumn(label: Text('Statut')),
                ],
                rows: [
                  for (final a in anomalies)
                    DataRow(
                      key: ValueKey(a.id),
                      selected: a.id == selectedId,
                      onSelectChanged: (_) => onTap(a),
                      cells: [
                        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.employeeName.isEmpty ? '—' : a.employeeName),
                          if (a.employeeNumber case final n?) Text(n, style: Theme.of(context).textTheme.bodySmall),
                        ])),
                        DataCell(Text(a.siteName ?? '—')),
                        DataCell(Text(a.assistedByName.isEmpty ? '—' : a.assistedByName)),
                        DataCell(Text(formatDateTime(a.occuredAt))),
                        DataCell(Text(anomalyEntryTypeLabel(a.entryType))),
                        DataCell(Text(anomalyStatusLabel(a.status))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
