import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../employee_controller.dart';
import '../employee_model.dart';
import '../widgets/employee_card.dart';
import '../widgets/employee_detail_view.dart';
import '../widgets/employee_table.dart';
import '../widgets/employee_toolbar.dart';
import 'employee_create_page.dart';
import 'employee_detail_page.dart';

/// Back-office : liste filtrable et paginée. Détail en panneau à droite sur grand écran,
/// en page plein écran sinon.
class EmployeeWebScreen extends ConsumerStatefulWidget {
  const EmployeeWebScreen({super.key});

  @override
  ConsumerState<EmployeeWebScreen> createState() => _EmployeeWebScreenState();
}

class _EmployeeWebScreenState extends ConsumerState<EmployeeWebScreen> {
  String? _selectedId;

  EmployeeController get _controller => ref.read(employeeControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_controller.refresh);
  }

  void _open(Employee employee) {
    if (Breakpoints.of(context) == WindowSize.expanded) {
      setState(() => _selectedId = employee.id);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EmployeeDetailPage(id: employee.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(employeeControllerProvider, (prev, next) {
      // Erreur alors qu'une liste est affichée (rafraîchissement) : on la garde et on prévient.
      if (next.error != null && next.items.isNotEmpty && prev?.error != next.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(next.error!)));
      }
    });
    final state = ref.watch(employeeControllerProvider);
    final window = Breakpoints.of(context);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (window != WindowSize.compact) ...[
        // En compact, le titre est déjà dans l'AppBar de la coquille.
        Text('Employés', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
      ],
      EmployeeToolbar(
        filters: state.filters,
        compact: window == WindowSize.compact,
        onChanged: _controller.setFilters,
        onCreate: () => openEmployeeCreate(context, asDialog: window != WindowSize.compact),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 2, child: state.loading && state.items.isNotEmpty ? const LinearProgressIndicator() : null),
      const SizedBox(height: 8),
      Expanded(child: _body(state)),
      if (state.items.isNotEmpty)
        PaginationBar(
          offset: state.offset,
          count: state.items.length,
          total: state.total,
          onPrevious: state.page > 0 && !state.loading ? () => _controller.goToPage(state.page - 1) : null,
          onNext: state.hasMore && !state.loading ? () => _controller.goToPage(state.page + 1) : null,
        ),
    ]);

    final selected = _selectedId;
    if (window != WindowSize.expanded || selected == null) return list;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: list),
      const SizedBox(width: 24),
      SizedBox(
        width: 380,
        child: EmployeeDetailPanel(id: selected, onClose: () => setState(() => _selectedId = null)),
      ),
    ]);
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
    return LayoutBuilder(builder: (context, constraints) {
      final size = Breakpoints.fromWidth(constraints.maxWidth);
      if (size == WindowSize.compact) {
        return ListView.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => EmployeeCard(employee: state.items[i], onTap: () => _open(state.items[i])),
        );
      }
      return EmployeeTable(
        employees: state.items,
        showCreatedAt: size == WindowSize.expanded,
        selectedId: _selectedId,
        onTap: _open,
      );
    });
  }
}
