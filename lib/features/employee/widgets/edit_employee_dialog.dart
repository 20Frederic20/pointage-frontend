import 'package:flutter/material.dart';

import '../../../core/role.dart';
import '../employee_model.dart';

/// Ce qui a changé dans la fiche ; null = inchangé.
typedef EmployeeEdit = ({String? firstName, String? lastName, String? phone, Role? role});

/// « Modifier » : nom, téléphone et rôle. Les rôles proposés s'arrêtent à [maxRole] ;
/// le rôle n'est pas modifiable sur sa propre fiche ([ownRecord]).
class EditEmployeeDialog extends StatefulWidget {
  const EditEmployeeDialog({super.key, required this.employee, required this.maxRole, required this.ownRecord});
  final Employee employee;
  final Role maxRole;
  final bool ownRecord;

  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.employee.firstName ?? '');
  late final _lastName = TextEditingController(text: widget.employee.lastName ?? '');
  late final _phone = TextEditingController(text: widget.employee.phone ?? '');
  late Role _role = widget.employee.role;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _changed(TextEditingController c, String? before) {
    final value = c.text.trim();
    return value.isEmpty || value == (before ?? '') ? null : value;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final e = widget.employee;
    Navigator.of(context).pop<EmployeeEdit>((
      firstName: _changed(_firstName, e.firstName),
      lastName: _changed(_lastName, e.lastName),
      phone: _changed(_phone, e.phone),
      role: _role == e.role ? null : _role,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      for (final r in Role.values)
        if (r.index <= widget.maxRole.index || r == widget.employee.role) r,
    ];
    return AlertDialog(
      title: const Text("Modifier l'employé"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Prénom')),
            TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Nom')),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || (t.length >= 10 && t.length <= 20) ? null : 'Entre 10 et 20 caractères';
              },
            ),
            DropdownButtonFormField<Role>(
              key: const ValueKey('edit-role'),
              initialValue: _role,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Rôle',
                helperText: widget.ownRecord ? 'Vous ne pouvez pas modifier votre propre rôle.' : null,
              ),
              items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: widget.ownRecord ? null : (r) => setState(() => _role = r ?? _role),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}
