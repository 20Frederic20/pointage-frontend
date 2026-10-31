import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../anomaly_model.dart';

/// Ligne de liste pour les petits écrans.
class AnomalyCard extends StatelessWidget {
  const AnomalyCard({super.key, required this.anomaly, required this.onTap});
  final Anomaly anomaly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = anomaly.employeeName.isEmpty ? 'Employé inconnu' : anomaly.employeeName;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.report_problem_outlined)),
        title: Text(anomaly.employeeNumber == null ? name : '$name · ${anomaly.employeeNumber}',
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${anomalyEntryTypeLabel(anomaly.entryType)} · ${formatDateTime(anomaly.occuredAt)}\n${anomalyStatusLabel(anomaly.status)} · Site : ${anomaly.siteName ?? '—'}',
            overflow: TextOverflow.ellipsis,
            maxLines: 2),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
