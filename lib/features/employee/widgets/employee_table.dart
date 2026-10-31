import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../employee_model.dart';
import 'employee_badges.dart';
import 'employee_actions.dart';

/// Tableau pour les écrans moyens et grands. Défile horizontalement si la place manque.
class EmployeeTable extends StatelessWidget {
  const EmployeeTable({
    super.key,
    required this.employees,
    required this.onTap,
    this.showCreatedAt = true,
    this.selectedId,
  });

  final List<Employee> employees;
  final ValueChanged<Employee> onTap;
  final bool showCreatedAt;
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
                columns: [
                  const DataColumn(label: Text('Employé')),
                  const DataColumn(label: Text('Entreprise')),
                  const DataColumn(label: Text('Site')),
                  const DataColumn(label: Text('Rôle')),
                  const DataColumn(label: Text('Téléphone')),
                  const DataColumn(label: Text('Statut')),
                  if (showCreatedAt) const DataColumn(label: Text('Créé le')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final e in employees)
                    DataRow(
                      key: ValueKey(e.id),
                      selected: e.id == selectedId,
                      onSelectChanged: (_) => onTap(e),
                      cells: [
                        DataCell(_NameCell(employee: e)),
                        DataCell(Text(e.companyName ?? '—')),
                        DataCell(Text(e.currentSiteName ?? '—')),
                        DataCell(RoleBadge(role: e.role)),
                        DataCell(Text(e.phone ?? '—')),
                        DataCell(StatusPill(isActive: e.isActive)),
                        if (showCreatedAt) DataCell(Text(formatDate(e.createdAt))),
                        DataCell(EmployeeActions(employee: e, compact: true)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Le nom, et le matricule en dessous quand le compte a un nom.
class _NameCell extends StatelessWidget {
  const _NameCell({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    if (employee.displayName == employee.employeeNumber) return Text(employee.employeeNumber);
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(employee.displayName),
      Text(employee.employeeNumber, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
