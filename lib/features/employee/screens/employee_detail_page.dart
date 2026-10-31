import 'package:flutter/material.dart';

import '../widgets/employee_detail_view.dart';

/// Fiche en plein écran (téléphone, tablette, et mobile).
class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Employé')),
        body: SafeArea(child: EmployeeDetailView(id: id)),
      );
}
