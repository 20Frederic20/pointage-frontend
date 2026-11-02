import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/download/download.dart' as download;
import '../auth/session_provider.dart';
import 'period.dart';
import 'work_time_model.dart';
import 'work_time_repository.dart';

typedef SaveFile = void Function(Uint8List bytes, String filename, String mimeType);

/// Enregistrement d'un fichier exporté (remplacé en test).
final saveFileProvider = Provider<SaveFile>((ref) => download.saveFile);

String workTimeErrorMessage(Object e) => switch (e) {
      ApiException(:final message) => message,
      _ => 'Connexion au serveur impossible, réessayez.',
    };

/// Libellé du statut d'un pointage.
String validationStatusLabel(String status) => switch (status) {
      'COUNTED' => 'Compté',
      'PENDING' => 'En attente',
      'REJECTED' => 'Rejeté',
      _ => status,
    };

/// Libellé de l'origine d'un pointage.
String entrySourceLabel(String source) => switch (source) {
      'ASSISTED' => 'Pour un collègue',
      'MANAGER_ASSISTED' => 'Par un responsable',
      _ => 'Normal',
    };

class WorkTimeState {
  WorkTimeState({
    Period? period,
    this.companyDirectoryId,
    this.employeeId,
    this.entries = const [],
    this.entriesTotal = 0,
    this.entriesOffset = 0,
    this.entriesLoading = false,
    this.entriesError,
    this.report,
    this.reportLoading = false,
    this.reportError,
  }) : period = period ?? Period.today();

  static const limit = 50;

  final Period period;
  final String? companyDirectoryId;
  final String? employeeId;

  final List<TimeEntryRow> entries;
  final int entriesTotal;
  final int entriesOffset;
  final bool entriesLoading;
  final String? entriesError;

  /// Le rapport ignore le filtre employé côté serveur : la liste des employés sert au filtre.
  final WorkTimeReport? report;
  final bool reportLoading;
  final String? reportError;

  WorkTimeFilters get filters => WorkTimeFilters(employeeId: employeeId, companyDirectoryId: companyDirectoryId);

  /// Lignes de synthèse affichées (filtre employé appliqué).
  List<WorkTimeSummaryRow> get summary =>
      (report?.summary ?? const []).where((s) => employeeId == null || s.employeeId == employeeId).toList();

  bool get hasMore => entriesOffset + entries.length < entriesTotal;
  int get page => entriesOffset ~/ limit;

  WorkTimeState copyWith({
    Period? period,
    String? Function()? companyDirectoryId,
    String? Function()? employeeId,
    List<TimeEntryRow>? entries,
    int? entriesTotal,
    int? entriesOffset,
    bool? entriesLoading,
    String? Function()? entriesError,
    WorkTimeReport? Function()? report,
    bool? reportLoading,
    String? Function()? reportError,
  }) =>
      WorkTimeState(
        period: period ?? this.period,
        companyDirectoryId: companyDirectoryId != null ? companyDirectoryId() : this.companyDirectoryId,
        employeeId: employeeId != null ? employeeId() : this.employeeId,
        entries: entries ?? this.entries,
        entriesTotal: entriesTotal ?? this.entriesTotal,
        entriesOffset: entriesOffset ?? this.entriesOffset,
        entriesLoading: entriesLoading ?? this.entriesLoading,
        entriesError: entriesError != null ? entriesError() : this.entriesError,
        report: report != null ? report() : this.report,
        reportLoading: reportLoading ?? this.reportLoading,
        reportError: reportError != null ? reportError() : this.reportError,
      );
}

/// Back-office « Pointages » : la liste des pointages et le temps de travail d'une même période.
class WorkTimeController extends Notifier<WorkTimeState> {
  int _entriesGeneration = 0;
  int _reportGeneration = 0;

  @override
  WorkTimeState build() {
    ref.watch(sessionProvider.select((s) => s.value?.identifier));
    _entriesGeneration++;
    _reportGeneration++;
    return WorkTimeState();
  }

  Future<void> setPeriod(Period period) => _reload(state.copyWith(period: period));

  Future<void> setCompany(String? companyDirectoryId) =>
      _reload(state.copyWith(companyDirectoryId: () => companyDirectoryId, employeeId: () => null));

  Future<void> setEmployee(String? employeeId) => _reload(state.copyWith(employeeId: () => employeeId));

  Future<void> _reload(WorkTimeState next) {
    state = next.copyWith(entriesOffset: 0);
    return refresh();
  }

  Future<void> refresh() => Future.wait([loadEntries(offset: state.entriesOffset), loadReport()]);

  Future<void> goToPage(int page) => loadEntries(offset: page * WorkTimeState.limit);

  Future<void> loadEntries({int offset = 0}) async {
    final generation = ++_entriesGeneration;
    final (period, filters) = (state.period, state.filters);
    state = state.copyWith(entriesLoading: true, entriesError: () => null);
    try {
      final token = await requireAccessToken(ref);
      final page = await ref
          .read(workTimeRepositoryProvider)
          .entries(token, period: period, filters: filters, limit: WorkTimeState.limit, offset: offset);
      if (!ref.mounted || generation != _entriesGeneration) return;
      state = state.copyWith(
          entries: page.items, entriesTotal: page.total, entriesOffset: offset, entriesLoading: false);
    } catch (e) {
      if (ref.mounted && generation == _entriesGeneration) {
        state = state.copyWith(entriesLoading: false, entriesError: () => workTimeErrorMessage(e));
      }
    }
  }

  Future<void> loadReport() async {
    final generation = ++_reportGeneration;
    final period = state.period;
    final filters = WorkTimeFilters(companyDirectoryId: state.companyDirectoryId);
    state = state.copyWith(reportLoading: true, reportError: () => null);
    try {
      final token = await requireAccessToken(ref);
      final report = await ref.read(workTimeRepositoryProvider).report(token, period: period, filters: filters);
      if (!ref.mounted || generation != _reportGeneration) return;
      state = state.copyWith(report: () => report, reportLoading: false);
    } catch (e) {
      if (ref.mounted && generation == _reportGeneration) {
        state = state.copyWith(reportLoading: false, reportError: () => workTimeErrorMessage(e));
      }
    }
  }

  /// Recalcule la période (employés affichés) puis recharge. Renvoie le message à afficher.
  Future<String> recalculate() async {
    try {
      final token = await requireAccessToken(ref);
      final ids = state.employeeId != null
          ? [state.employeeId!]
          : state.companyDirectoryId != null
              ? state.summary.map((s) => s.employeeId).toList()
              : null;
      if (ids != null && ids.isEmpty) return 'Aucun employé à recalculer.';
      final r = await ref.read(workTimeRepositoryProvider).recalculate(token, period: state.period, employeeIds: ids);
      if (ref.mounted) await refresh();
      return '${r.recalculated} jours recalculés, ${r.skippedValidated} validés ignorés, ${r.failed} en échec.';
    } catch (e) {
      return workTimeErrorMessage(e);
    }
  }

  /// Exporte le temps de travail et l'enregistre. Renvoie le message d'erreur, ou null.
  Future<String?> export(ExportFormat format) async {
    try {
      final token = await requireAccessToken(ref);
      final period = state.period;
      final bytes =
          await ref.read(workTimeRepositoryProvider).export(token, period: period, filters: state.filters, format: format);
      ref.read(saveFileProvider)(bytes, format.filename(period), format.mimeType);
      return null;
    } catch (e) {
      return workTimeErrorMessage(e);
    }
  }
}

final workTimeControllerProvider = NotifierProvider<WorkTimeController, WorkTimeState>(WorkTimeController.new);
