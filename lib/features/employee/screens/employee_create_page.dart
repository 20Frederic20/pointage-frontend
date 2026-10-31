import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../employee_model.dart';
import '../widgets/employee_form.dart';

/// Message après la création ; l'email avait peut-être déjà un compte (autre entreprise).
String createdMessage(Employee created) => created.accountReused
    ? 'Ce compte existait déjà : une nouvelle fiche a été créée dans cette entreprise.'
    : 'Employé ${created.employeeNumber} créé';

/// Ouvre la création : dialogue (écrans moyens et grands) ou page plein écran (téléphone).
Future<void> openEmployeeCreate(BuildContext context, {required bool asDialog}) async {
  final messenger = ScaffoldMessenger.of(context);
  final created = asDialog
      ? await showDialog<Employee>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: EmployeeForm(title: 'Nouvel employé', onCreated: (e) => Navigator.of(dialogContext).pop(e)),
            ),
          ),
        )
      : await Navigator.of(context).push<Employee>(MaterialPageRoute(builder: (_) => const EmployeeCreatePage()));
  if (created != null) {
    messenger.showSnackBar(
      SnackBar(backgroundColor: AppColors.green, content: Text(createdMessage(created))),
    );
  }
}

class EmployeeCreatePage extends StatelessWidget {
  const EmployeeCreatePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nouvel employé')),
        body: SafeArea(child: EmployeeForm(onCreated: (e) => Navigator.of(context).pop(e))),
      );
}
