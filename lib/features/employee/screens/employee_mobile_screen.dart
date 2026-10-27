import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import '../widgets/employee_card.dart';
import 'employee_detail_page.dart';

/// Mobile, pour les responsables : liste des employés (recherche par matricule, défilement infini)
/// d'où l'on peut faire pointer un employé.
class EmployeeMobileScreen extends ConsumerStatefulWidget {
  const EmployeeMobileScreen({super.key});

  @override
  ConsumerState<EmployeeMobileScreen> createState() => _EmployeeMobileScreenState();
}

class _EmployeeMobileScreenState extends ConsumerState<EmployeeMobileScreen> {
  EmployeeController get _controller => ref.read(employeeControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Repart d'une liste sans filtre : le contrôleur est partagé avec le back-office.
    Future.microtask(() => _controller.setFilters(const EmployeeFilters()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Employés')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SearchField(
              label: 'Matricule',
              onChanged: (v) => _controller.setFilters(EmployeeFilters(search: v)),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 2, child: state.loading && state.items.isNotEmpty ? const LinearProgressIndicator() : null),
            const SizedBox(height: 8),
            Expanded(child: _body(state)),
          ]),
        ),
      ),
    );
  }

  Widget _body(EmployeeState state) {
    if (state.loading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(message: state.error!, onRetry: _controller.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.badge_outlined,
        message: state.filters.isEmpty ? 'Aucun employé' : 'Aucun résultat pour ces filtres',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _controller.loadMore();
        return false;
      },
      child: ListView.separated(
        itemCount: state.items.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i >= state.items.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final e = state.items[i];
          return EmployeeCard(
            employee: e,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EmployeeDetailPage(id: e.id))),
          );
        },
      ),
    );
  }
}
