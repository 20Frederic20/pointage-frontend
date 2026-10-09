import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointage/features/employee/employee_controller.dart';

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(employeeControllerProvider.notifier).fetchEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    // On écoute l'état des employés
    final state = ref.watch(employeeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Employés'),
      ),
      body: Builder(
        builder: (context) {
          // 1. Cas du chargement initial (si la liste est vide et qu'on charge)
          if (state.loading && state.employees.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Cas d'une erreur
          if (state.error != null && state.employees.isEmpty) {
            return Center(
              child: Text(
                'Erreur : ${state.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. Cas où la liste est vide
          if (state.employees.isEmpty) {
            return const Center(child: Text('Aucun employé trouvé.'));
          }

          // 4. Affichage de la liste + mise en avant du "dernier"
          return Column(
            children: [
              // Optionnel : un encadré pour afficher le dernier enregistré
              if (state.last != null)
                Container(
                  padding: const EdgeInsets.all(16), // ou EdgeInsets.all(16)
                  color: Colors.blue.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 12),
                      Text('Dernier : ${state.last!.employeeNumber}'),
                    ],
                  ),
                ),

              // La liste complète des employés
              Expanded(
                child: ListView.builder(
                  itemCount: state.employees.length,
                  itemBuilder: (context, index) {
                    final employee = state.employees[index];
                    return ListTile(
                      title: Text(employee.employeeNumber),
                      subtitle: Text(employee.role ?? 'Aucun rôle'),
                      trailing: Text(employee.phone ?? ''),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}