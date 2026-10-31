import 'package:flutter/material.dart';

import '../../../core/role.dart';

class RoleFilterField extends StatelessWidget {
  const RoleFilterField({super.key, required this.value, required this.onChanged, this.width});
  final Role? value;
  final ValueChanged<Role?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<Role?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rôle', isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les rôles')),
            for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: onChanged,
        ),
      );
}

class StatusFilterField extends StatelessWidget {
  const StatusFilterField({super.key, required this.value, required this.onChanged, this.width});
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<bool?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Statut', isDense: true),
          items: const [
            DropdownMenuItem(value: null, child: Text('Tous les statuts')),
            DropdownMenuItem(value: true, child: Text('Actifs')),
            DropdownMenuItem(value: false, child: Text('Inactifs')),
          ],
          onChanged: onChanged,
        ),
      );
}
