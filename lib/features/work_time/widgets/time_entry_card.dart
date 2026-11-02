import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../work_time_controller.dart';
import '../work_time_model.dart';

/// Un pointage, pour les petits écrans.
class TimeEntryCard extends StatelessWidget {
  const TimeEntryCard({super.key, required this.entry});
  final TimeEntryRow entry;

  @override
  Widget build(BuildContext context) {
    final origin = entry.assistedByName == null
        ? entrySourceLabel(entry.source)
        : '${entrySourceLabel(entry.source)} (${entry.assistedByName})';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(child: Icon(entry.isIn ? Icons.login : Icons.logout)),
        title: Text('${entry.displayName} · ${entry.employeeNumber}', overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${entry.isIn ? 'Entrée' : 'Sortie'} · ${formatDateTime(entry.occuredAt)} · ${entry.siteName ?? '—'}\n'
          '${validationStatusLabel(entry.validationStatus)} · $origin',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
      ),
    );
  }
}
