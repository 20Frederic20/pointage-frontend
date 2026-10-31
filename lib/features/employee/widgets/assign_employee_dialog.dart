import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../directory/directory_controller.dart';
import '../../directory/directory_model.dart';
import '../employee_model.dart';

/// La nouvelle affectation choisie.
typedef AssignmentChoice = ({String directoryId, String siteId, DateTime startDate, DateTime? endDate});

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// L'annuaire racine [companyId] et tous ses services ; tous les annuaires quand l'entreprise est inconnue.
List<Directory> companyDirectories(List<Directory> all, String? companyId) {
  if (companyId == null) return all;
  final inside = {companyId};
  var grew = true;
  while (grew) {
    grew = false;
    for (final d in all) {
      if (d.parentDirectoryId != null && inside.contains(d.parentDirectoryId) && inside.add(d.id)) grew = true;
    }
  }
  return [for (final d in all) if (inside.contains(d.id)) d];
}

/// « Affecter à un site » : service, site, date de début (aujourd'hui ou plus tard) et date de fin facultative.
class AssignEmployeeDialog extends ConsumerStatefulWidget {
  const AssignEmployeeDialog({super.key, required this.employee});
  final Employee employee;

  @override
  ConsumerState<AssignEmployeeDialog> createState() => _AssignEmployeeDialogState();
}

class _AssignEmployeeDialogState extends ConsumerState<AssignEmployeeDialog> {
  late String? _directoryId = widget.employee.companyDirectoryId;
  String? _siteId;
  DateTime _start = _today();
  DateTime? _end;

  Future<DateTime?> _pick(DateTime initial, DateTime first) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: DateTime(_today().year + 5),
      );

  @override
  Widget build(BuildContext context) {
    final directories = ref.watch(allDirectoriesProvider);
    final sites = _directoryId == null ? null : ref.watch(directorySitesProvider(_directoryId!));
    final siteItems = sites?.value ?? const <Site>[];
    // Le site principal (premier de la liste) par défaut.
    final siteId = _siteId ?? (siteItems.isEmpty ? null : siteItems.first.id);
    final current = widget.employee.currentSiteName;
    return AlertDialog(
      title: const Text('Affecter à un site'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            key: ValueKey('assign-directory-$_directoryId'),
            initialValue: _directoryId,
            decoration: const InputDecoration(labelText: 'Service'),
            items: [
              for (final d in companyDirectories(directories.value ?? const [], widget.employee.companyDirectoryId))
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() {
              _directoryId = v;
              _siteId = null;
            }),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('assign-site-$_directoryId'),
            initialValue: siteId,
            decoration: const InputDecoration(labelText: 'Site'),
            items: [for (final s in siteItems) DropdownMenuItem(value: s.id, child: Text(s.name))],
            onChanged: (v) => setState(() => _siteId = v),
          ),
          ListTile(
            key: const ValueKey('assign-start'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de début'),
            subtitle: Text(formatDate(_start)),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final d = await _pick(_start, _today());
              if (d != null) setState(() => _start = d);
            },
          ),
          ListTile(
            key: const ValueKey('assign-end'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de fin (facultative)'),
            subtitle: Text(_end == null ? 'Sans fin' : formatDate(_end)),
            trailing: _end == null
                ? const Icon(Icons.event)
                : IconButton(tooltip: 'Sans fin', icon: const Icon(Icons.clear), onPressed: () => setState(() => _end = null)),
            onTap: () async {
              final d = await _pick(_end ?? _start, _start);
              if (d != null) setState(() => _end = d);
            },
          ),
          if (current != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "L'affectation actuelle à $current se terminera le "
                '${formatDate(_start.subtract(const Duration(days: 1)))}.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _directoryId == null || siteId == null
              ? null
              : () => Navigator.of(context).pop<AssignmentChoice>(
                  (directoryId: _directoryId!, siteId: siteId, startDate: _start, endDate: _end)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
