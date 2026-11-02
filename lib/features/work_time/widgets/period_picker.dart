import 'package:flutter/material.dart';

import '../period.dart';

/// Choix de la période : préréglages ou plage personnalisée.
class PeriodPicker extends StatelessWidget {
  const PeriodPicker({super.key, required this.period, required this.onChanged});

  final Period period;
  final ValueChanged<Period> onChanged;

  static const _custom = 'custom';

  Future<void> _pickRange(BuildContext context) async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(start: period.from, end: period.to),
      helpText: 'Période (62 jours maximum)',
      saveText: 'Valider',
    );
    if (range != null) onChanged(Period(range.start, range.end));
  }

  @override
  Widget build(BuildContext context) {
    final presets = {
      "Aujourd'hui": Period.today(),
      'Hier': Period.yesterday(),
      'Cette semaine': Period.thisWeek(),
      'Ce mois-ci': Period.thisMonth(),
    };
    return PopupMenuButton<String>(
      tooltip: 'Choisir la période',
      onSelected: (key) => key == _custom ? _pickRange(context) : onChanged(presets[key]!),
      itemBuilder: (_) => [
        for (final label in presets.keys) PopupMenuItem(value: label, child: Text(label)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _custom, child: Text('Personnalisée…')),
      ],
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Période',
          prefixIcon: Icon(Icons.date_range_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down),
          isDense: true,
        ),
        child: Text(period.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
