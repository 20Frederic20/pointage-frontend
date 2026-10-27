import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../anomaly_controller.dart';
import '../anomaly_model.dart';
import '../widgets/anomaly_card.dart';
import '../widgets/anomaly_detail_view.dart';
import '../widgets/anomaly_table.dart';

const _statusFilters = <String?, String>{
  'OPEN': 'À traiter',
  'VALIDATED': 'Validées',
  'REJECTED': 'Rejetées',
  null: 'Toutes',
};

/// Back-office : anomalies de pointage à valider ou rejeter. Détail en panneau sur grand écran,
/// en page plein écran sinon.
class AnomalyWebScreen extends ConsumerStatefulWidget {
  const AnomalyWebScreen({super.key});

  @override
  ConsumerState<AnomalyWebScreen> createState() => _AnomalyWebScreenState();
}

class _AnomalyWebScreenState extends ConsumerState<AnomalyWebScreen> {
  String? _selectedId;

  AnomalyController get _controller => ref.read(anomalyControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_controller.refresh);
  }

  void _open(Anomaly anomaly) {
    if (Breakpoints.of(context) == WindowSize.expanded) {
      setState(() => _selectedId = anomaly.id);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _AnomalyDetailPage(id: anomaly.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(anomalyControllerProvider, (prev, next) {
      if (next.error != null && next.items.isNotEmpty && prev?.error != next.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: AppColors.red, content: Text(next.error!)));
      }
    });
    final state = ref.watch(anomalyControllerProvider);
    final window = Breakpoints.of(context);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (window != WindowSize.compact) ...[
        Text('Anomalies', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in _statusFilters.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: state.status == entry.key,
            onSelected: (_) => _controller.setStatus(entry.key),
          ),
      ]),
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

    final selected = state.items.where((a) => a.id == _selectedId).firstOrNull;
    if (window != WindowSize.expanded || selected == null) return list;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: list),
      const SizedBox(width: 24),
      SizedBox(
        width: 380,
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
                tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedId = null)),
          ),
          Expanded(
            child: AnomalyDetailView(
              key: ValueKey(selected.id),
              anomaly: selected,
              onDecided: () => setState(() => _selectedId = null),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _body(AnomalyState state) {
    if (state.loading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(message: state.error!, onRetry: _controller.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.report_problem_outlined,
        message: state.status == 'OPEN' ? 'Aucune anomalie à traiter' : 'Aucune anomalie',
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      if (Breakpoints.fromWidth(constraints.maxWidth) == WindowSize.compact) {
        return ListView.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => AnomalyCard(anomaly: state.items[i], onTap: () => _open(state.items[i])),
        );
      }
      return AnomalyTable(anomalies: state.items, selectedId: _selectedId, onTap: _open);
    });
  }
}

/// Détail plein écran. Se ferme après une décision.
class _AnomalyDetailPage extends ConsumerWidget {
  const _AnomalyDetailPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomaly = ref.watch(anomalyControllerProvider).items.where((a) => a.id == id).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Anomalie')),
      body: SafeArea(
        child: anomaly == null
            ? const EmptyState(icon: Icons.report_problem_outlined, message: 'Anomalie introuvable')
            : AnomalyDetailView(anomaly: anomaly, onDecided: () => Navigator.of(context).maybePop()),
      ),
    );
  }
}
