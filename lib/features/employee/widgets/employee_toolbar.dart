import 'package:flutter/material.dart';

import '../../../core/widgets/search_field.dart';
import '../employee_model.dart';
import 'employee_filter_fields.dart';

/// Recherche, filtres et création. Passe à la ligne quand la place manque ;
/// en [compact], les champs prennent toute la largeur et le bouton devient une icône.
class EmployeeToolbar extends StatelessWidget {
  const EmployeeToolbar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onCreate,
    this.compact = false,
  });

  final EmployeeFilters filters;
  final ValueChanged<EmployeeFilters> onChanged;
  final VoidCallback onCreate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fieldWidth = compact ? double.infinity : 200.0;
    return Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
        width: compact ? double.infinity : 280,
        child: SearchField(
          label: 'Matricule',
          initialValue: filters.search,
          onChanged: (v) => onChanged(EmployeeFilters(search: v, role: filters.role, isActive: filters.isActive)),
        ),
      ),
      RoleFilterField(
        width: fieldWidth,
        value: filters.role,
        onChanged: (r) => onChanged(EmployeeFilters(search: filters.search, role: r, isActive: filters.isActive)),
      ),
      StatusFilterField(
        width: fieldWidth,
        value: filters.isActive,
        onChanged: (a) => onChanged(EmployeeFilters(search: filters.search, role: filters.role, isActive: a)),
      ),
      if (compact)
        IconButton.filled(tooltip: 'Nouvel employé', icon: const Icon(Icons.add), onPressed: onCreate)
      else
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Nouvel employé')),
    ]);
  }
}
