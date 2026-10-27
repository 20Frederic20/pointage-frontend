import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../employee_model.dart';
import 'employee_badges.dart';
import 'punch_for_employee_button.dart';

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
                  const DataColumn(label: Text('Matricule')),
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
                        DataCell(Text(e.employeeNumber)),
                        DataCell(RoleBadge(role: e.role)),
                        DataCell(Text(e.phone ?? '—')),
                        DataCell(StatusPill(isActive: e.isActive)),
                        if (showCreatedAt) DataCell(Text(formatDate(e.createdAt))),
                        DataCell(PunchForEmployeeButton(employee: e)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
