import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../features/anomaly/anomaly_model.dart';
import '../../features/anomaly/anomaly_repository.dart';
import '../../features/auth/session_provider.dart';
import '../../features/work_time/period.dart';
import '../../features/work_time/work_time_model.dart';
import '../../features/work_time/work_time_repository.dart';
import '../admin_routes.dart';

/// Ce que le tableau de bord affiche pour aujourd'hui.
class DashboardData {
  DashboardData({required this.report, required this.openAnomalies, required this.openAnomalyCount});

  final WorkTimeReport report;
  final List<Anomaly> openAnomalies;
  final int openAnomalyCount;

  Iterable<WorkTimeDay> get _today => report.days;
  int count(DayState s) => _today.where((d) => d.state == s).length;
  int get late => _today.where((d) => d.late > Duration.zero).length;
  int get overtime => _today.where((d) => d.overtime).length;

  /// Les retards du jour, le plus long d'abord.
  List<WorkTimeDay> get lateDays => [..._today.where((d) => d.late > Duration.zero)]
    ..sort((a, b) => b.late.compareTo(a.late));

  String nameOf(String employeeId) =>
      report.summary.where((s) => s.employeeId == employeeId).firstOrNull?.displayName ?? employeeId;
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final token = await requireAccessToken(ref);
  final (report, anomalies) = await (
    ref.read(workTimeRepositoryProvider).report(token, period: Period.today()),
    ref.read(anomalyRepositoryProvider).list(token, status: 'OPEN', limit: 5),
  ).wait;
  return DashboardData(report: report, openAnomalies: anomalies.items, openAnomalyCount: anomalies.total);
}, retry: (_, _) => null);

/// Accueil du back-office : la journée en chiffres, les retards du jour et les anomalies à traiter.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KiteText.of(context);
    final c = KiteColors.of(context);
    final now = DateTime.now();
    return switch (ref.watch(dashboardProvider)) {
      AsyncData(value: final data) => ListView(children: [
          Row(children: [
            Expanded(child: Text("Aujourd'hui · ${formatDate(now)}", style: t.muted)),
            IconButton(
              tooltip: 'Actualiser',
              iconSize: 18,
              color: c.mutedForeground,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(dashboardProvider),
            ),
          ]),
          const SizedBox(height: KiteSpace.md),
          KiteStatGrid(height: 156, minTileWidth: 180, children: [
            _Stat(label: 'Présents', value: data.count(DayState.present),
                note: _plural(data.count(DayState.notYetArrived), 'pas encore arrivé')),
            _Stat(label: 'Absents', value: data.count(DayState.absent)),
            _Stat(label: 'En retard', value: data.late),
            _Stat(label: 'Heures sup.', value: data.overtime, note: data.overtime == 0 ? null : 'journées'),
            _Stat(label: 'Anomalies en attente', value: data.openAnomalyCount),
          ]),
          const SizedBox(height: KiteSpace.lg),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              KiteCard(
                key: const ValueKey('dashboard-late'),
                title: 'Retards du jour',
                child: data.lateDays.isEmpty
                    ? Text('Aucun retard.', style: t.muted)
                    : Column(children: [
                        for (final d in data.lateDays.take(8))
                          _Line(title: data.nameOf(d.employeeId), trailing: '${d.late.inMinutes} min'),
                      ]),
              ),
              KiteCard(
                key: const ValueKey('dashboard-anomalies'),
                title: 'Anomalies en attente',
                trailing: TextButton(onPressed: () => context.go(AdminPaths.anomalies), child: const Text('Voir toutes')),
                child: data.openAnomalies.isEmpty
                    ? Text('Rien à traiter.', style: t.muted)
                    : Column(children: [
                        for (final a in data.openAnomalies)
                          _Line(
                            title: a.employeeName,
                            subtitle: a.assistedByName.isEmpty ? null : 'Pointé depuis le téléphone de ${a.assistedByName}',
                            trailing: formatDateTime(a.occuredAt),
                          ),
                      ]),
              ),
            ];
            if (constraints.maxWidth < 900) {
              return Column(children: [cards[0], const SizedBox(height: KiteSpace.lg), cards[1]]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: cards[0]),
              const SizedBox(width: KiteSpace.lg),
              Expanded(child: cards[1]),
            ]);
          }),
        ]),
      AsyncError(:final error) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error is ApiException ? error.message : 'Tableau de bord indisponible.', style: t.muted),
            const SizedBox(height: KiteSpace.md),
            OutlinedButton(onPressed: () => ref.invalidate(dashboardProvider), child: const Text('Réessayer')),
          ]),
        ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

String? _plural(int n, String label) => n == 0 ? null : '$n $label${n > 1 ? 's' : ''}';

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.note});

  final String label;
  final int value;
  final String? note;

  @override
  Widget build(BuildContext context) =>
      KiteStat(key: const ValueKey('dashboard-stat'), label: label, value: '$value', delta: note);
}

class _Line extends StatelessWidget {
  const _Line({required this.title, this.subtitle, required this.trailing});

  final String title;
  final String? subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KiteSpace.xs),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.small, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: t.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: KiteSpace.md),
        Text(trailing, style: t.muted.copyWith(fontSize: 12)),
      ]),
    );
  }
}
