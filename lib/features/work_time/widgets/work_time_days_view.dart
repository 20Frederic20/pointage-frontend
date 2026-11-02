import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../work_time_model.dart';

const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// Le détail jour par jour d'un employé (les jours non travaillés sont omis).
class WorkTimeDaysView extends StatelessWidget {
  const WorkTimeDaysView({super.key, required this.days});
  final List<WorkTimeDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Center(child: Text('Aucune journée sur la période.'));
    final sorted = [...days]..sort((a, b) => b.workDate.compareTo(a.workDate));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _DayTile(day: sorted[i]),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});
  final WorkTimeDay day;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (day.state) {
      DayState.present => (Icons.check_circle_outline, Colors.green),
      DayState.toCheck => (Icons.warning_amber_outlined, Colors.orange),
      DayState.notCalculated => (Icons.hourglass_empty, Colors.grey),
      DayState.absent => (Icons.event_busy_outlined, Colors.red),
      DayState.notYetArrived => (Icons.schedule, Colors.blueGrey),
    };
    final counted = day.state == DayState.present || day.state == DayState.toCheck;
    final details = [
      if (day.firstIn != null || day.lastOut != null) '${formatTime(day.firstIn)} → ${formatTime(day.lastOut)}',
      if (counted) '${formatDuration(day.worked)} travaillées',
      if (counted && day.late > Duration.zero) 'retard ${formatDuration(day.late)}',
      if (day.overtime) 'heures supp.',
      ?day.absenceType,
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Row(children: [
          Flexible(
            child: Text('${_weekdays[day.workDate.weekday - 1]} ${formatDate(day.workDate)}',
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(day.state.label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
        subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      ),
    );
  }
}
