import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/session_provider.dart';
import '../period.dart';
import '../work_time_controller.dart';
import '../work_time_model.dart';
import '../work_time_repository.dart';
import '../widgets/period_picker.dart';
import '../widgets/time_entries_table.dart' show StatusChip;

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

/// Pointages et totaux de l'employé connecté : sans filtre, le backend s'en tient à sa fiche.
final myTimeEntriesProvider =
    FutureProvider.autoDispose.family<(List<TimeEntryRow>, WorkTimeSummaryRow?), Period>((ref, period) async {
  final token = await requireAccessToken(ref);
  final repo = ref.read(workTimeRepositoryProvider);
  final entries = repo.entries(token, period: period, limit: 500);
  final report = repo.report(token, period: period);
  await Future.wait([entries, report]); // lève la première erreur telle quelle
  return ((await entries).items, (await report).summary.firstOrNull);
}, retry: (_, _) => null);

/// Mobile : « Mes pointages ».
class MyTimeEntriesScreen extends ConsumerStatefulWidget {
  const MyTimeEntriesScreen({super.key});

  @override
  ConsumerState<MyTimeEntriesScreen> createState() => _MyTimeEntriesScreenState();
}

class _MyTimeEntriesScreenState extends ConsumerState<MyTimeEntriesScreen> {
  Period _period = Period.today();

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(myTimeEntriesProvider(_period));
    return Scaffold(
      appBar: AppBar(title: const Text('Mes pointages')),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: PeriodPicker(period: _period, onChanged: (p) => setState(() => _period = p)),
          ),
          Expanded(
            child: switch (data) {
              AsyncValue(:final value?, isLoading: false) || AsyncValue(:final value?, hasError: false) =>
                _content(value.$1, value.$2),
              AsyncError(:final error) => ErrorState(
                  message: workTimeErrorMessage(error),
                  onRetry: () => ref.invalidate(myTimeEntriesProvider(_period)),
                ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ]),
      ),
    );
  }

  Widget _content(List<TimeEntryRow> entries, WorkTimeSummaryRow? totals) {
    final byDay = <DateTime, List<TimeEntryRow>>{};
    for (final e in entries) {
      byDay.putIfAbsent(DateTime(e.occuredAt.year, e.occuredAt.month, e.occuredAt.day), () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myTimeEntriesProvider(_period).future),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        _Totals(totals: totals),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: EmptyState(icon: Icons.history, message: 'Aucun pointage sur la période'),
          ),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('${_days[day.weekday - 1]} ${formatDate(day)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          for (final e in byDay[day]!..sort((a, b) => a.occuredAt.compareTo(b.occuredAt)))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: Icon(e.isIn ? Icons.login : Icons.logout),
                title: Text('${e.isIn ? 'Entrée' : 'Sortie'} · ${formatTime(e.occuredAt)}'),
                subtitle: e.siteName == null && e.assistedByName == null
                    ? null
                    : Text([?e.siteName, if (e.assistedByName case final n?) 'par $n'].join(' · '),
                        overflow: TextOverflow.ellipsis),
                trailing: e.validationStatus == 'COUNTED' ? null : StatusChip(status: e.validationStatus),
              ),
            ),
        ],
      ]),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final WorkTimeSummaryRow? totals;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final tiles = [
      ('Heures travaillées', formatDuration(t?.workedTotal ?? Duration.zero), Icons.timer_outlined),
      ('Jours présents', '${t?.presentDays ?? 0}', Icons.event_available_outlined),
      ('Retards', '${t?.lateDays ?? 0}', Icons.running_with_errors_outlined),
      ('Heures supp.', '${t?.overtimeDays ?? 0}', Icons.more_time_outlined),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        for (final (label, value, icon) in tiles)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                ]),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ],
    );
  }
}
