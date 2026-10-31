import 'package:flutter/material.dart';

import '../employee_model.dart';
import 'employee_badges.dart';
import 'employee_actions.dart';

/// Ligne de liste pour les petits écrans (web compact et mobile).
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee, required this.onTap});
  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
          title: Text(employee.displayName, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              RoleBadge(role: employee.role),
              StatusPill(isActive: employee.isActive),
              if (employee.displayName != employee.employeeNumber) Text(employee.employeeNumber),
              if (employee.phone case final phone?) Text(phone),
              if ([?employee.companyName, ?employee.currentSiteName] case final place when place.isNotEmpty)
                Text(place.join(' · ')),
              // Les icônes d'action sous les informations : la largeur d'un téléphone ne suffit pas à droite.
              EmployeeActions(employee: employee, compact: true),
            ]),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
