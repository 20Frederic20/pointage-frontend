import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../../directory/directory_controller.dart';
import '../work_time_controller.dart';
import '../work_time_model.dart';
import '../widgets/period_picker.dart';
import '../widgets/time_entries_table.dart';
import '../widgets/time_entry_card.dart';
import '../widgets/work_time_days_view.dart';
import '../widgets/work_time_summary_card.dart';
import '../widgets/work_time_summary_table.dart';

/// Back-office : les pointages et le temps de travail d'une période (aujourd'hui par défaut),
/// avec le recalcul et les exports.
class WorkTimeWebScreen extends ConsumerStatefulWidget {
  const WorkTimeWebScreen({super.key});

  @override
  ConsumerState<WorkTimeWebScreen> createState() => _WorkTimeWebScreenState();
}

class _WorkTimeWebScreenState extends ConsumerState<WorkTimeWebScreen> {
  bool _busy = false;

  WorkTimeController get _controller => ref.read(workTimeControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_controller.refresh);
  }

  void _snack(String message, {bool error = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(backgroundColor: error ? AppColors.red : null, content: Text(message)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDays(WorkTimeSummaryRow row) {
    final days = (ref.read(workTimeControllerProvider).report?.days ?? const <WorkTimeDay>[])
        .where((d) => d.employeeId == row.employeeId)
        .toList();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(row.displayName)),
        body: SafeArea(child: WorkTimeDaysView(days: days)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workTimeControllerProvider);
    final compact = Breakpoints.of(context) == WindowSize.compact;
    return DefaultTabController(
      length: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!compact) ...[
          Text('Pointages', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
        ],
        _Filters(state: state, controller: _controller),
        const TabBar(tabs: [Tab(text: 'Pointages'), Tab(text: 'Temps de travail')]),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [
            _entriesTab(state),
            _workTimeTab(state),
          ]),
        ),
      ]),
    );
  }

  Widget _entriesTab(WorkTimeState state) {
    final Widget body;
    if (state.entriesLoading && state.entries.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.entriesError != null) {
      body = ErrorState(message: state.entriesError!, onRetry: () => _controller.loadEntries(offset: state.entriesOffset));
    } else if (state.entries.isEmpty) {
      body = const EmptyState(icon: Icons.schedule_outlined, message: 'Aucun pointage sur la période');
    } else {
      body = LayoutBuilder(builder: (context, constraints) {
        if (Breakpoints.fromWidth(constraints.maxWidth) != WindowSize.expanded) {
          return ListView.separated(
            itemCount: state.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => TimeEntryCard(entry: state.entries[i]),
          );
        }
        return TimeEntriesTable(entries: state.entries);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 2, child: state.entriesLoading && state.entries.isNotEmpty ? const LinearProgressIndicator() : null),
      const SizedBox(height: 8),
      Expanded(child: body),
      if (state.entries.isNotEmpty)
        PaginationBar(
          offset: state.entriesOffset,
          count: state.entries.length,
          total: state.entriesTotal,
          onPrevious: state.page > 0 && !state.entriesLoading ? () => _controller.goToPage(state.page - 1) : null,
          onNext: state.hasMore && !state.entriesLoading ? () => _controller.goToPage(state.page + 1) : null,
        ),
    ]);
  }

  Widget _workTimeTab(WorkTimeState state) {
    final rows = state.summary;
    final Widget body;
    if (state.reportLoading && state.report == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.reportError != null) {
      body = ErrorState(message: state.reportError!, onRetry: _controller.loadReport);
    } else if (rows.isEmpty) {
      body = const EmptyState(icon: Icons.timer_outlined, message: 'Aucun employé sur la période');
    } else {
      body = LayoutBuilder(builder: (context, constraints) {
        if (Breakpoints.fromWidth(constraints.maxWidth) != WindowSize.expanded) {
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => WorkTimeSummaryCard(row: rows[i], onTap: () => _openDays(rows[i])),
          );
        }
        return WorkTimeSummaryTable(rows: rows, onTap: _openDays);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
        FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final message = await _controller.recalculate();
                    if (mounted) _snack(message);
                  }),
          icon: const Icon(Icons.refresh),
          label: const Text('Recalculer'),
        ),
        MenuAnchor(
          menuChildren: [
            for (final format in ExportFormat.values)
              MenuItemButton(
                onPressed: () => _run(() async {
                  final error = await _controller.export(format);
                  if (error != null && mounted) _snack(error, error: true);
                }),
                child: Text(format.label),
              ),
          ],
          builder: (context, menu, _) => OutlinedButton.icon(
            onPressed: _busy ? null : () => menu.isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Exporter'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
          height: 2,
          child: _busy || (state.reportLoading && state.report != null) ? const LinearProgressIndicator() : null),
      const SizedBox(height: 8),
      Expanded(child: body),
    ]);
  }
}

/// Période, entreprise et employé : communs aux deux onglets.
class _Filters extends ConsumerWidget {
  const _Filters({required this.state, required this.controller});

  final WorkTimeState state;
  final WorkTimeController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = (ref.watch(allDirectoriesProvider).value ?? const []).where((d) => d.isCompany).toList();
    final employees = state.report?.summary ?? const <WorkTimeSummaryRow>[];
    const width = 260.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, child: PeriodPicker(period: state.period, onChanged: controller.setPeriod)),
        if (companies.isNotEmpty)
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String?>(
              initialValue: state.companyDirectoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Entreprise', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toutes')),
                for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: controller.setCompany,
            ),
          ),
        if (employees.isNotEmpty)
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String?>(
              key: ValueKey(state.companyDirectoryId),
              initialValue: state.employeeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Employé', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous')),
                for (final e in employees)
                  DropdownMenuItem(value: e.employeeId, child: Text(e.displayName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: controller.setEmployee,
            ),
          ),
      ]),
    );
  }
}
