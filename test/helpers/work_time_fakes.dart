import 'dart:typed_data';

import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/paged.dart';
import 'package:pointage/features/work_time/period.dart';
import 'package:pointage/features/work_time/work_time_model.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

TimeEntryRow fakeEntry(int n, {String source = 'MOBILE', String status = 'COUNTED'}) => TimeEntryRow(
      id: 't$n',
      employeeId: 'emp$n',
      employeeNumber: 'EMP${n.toString().padLeft(7, '0')}',
      firstName: 'Ana$n',
      lastName: 'Dossou',
      companyName: 'Société R',
      siteName: 'Siège',
      entryType: n.isOdd ? 'IN' : 'OUT',
      occuredAt: DateTime(2026, 11, 2, 8, n),
      source: source,
      validationStatus: status,
      assistedByName: source == 'MOBILE' ? null : 'Paul Kpade',
    );

WorkTimeSummaryRow fakeSummary(int n, {int toCheck = 0, int notCalculated = 0}) => WorkTimeSummaryRow(
      employeeId: 'emp$n',
      employeeNumber: 'EMP${n.toString().padLeft(7, '0')}',
      firstName: 'Ana$n',
      lastName: 'Dossou',
      companyName: 'Société R',
      presentDays: 3,
      absentDays: 1,
      lateDays: 1,
      lateTotal: const Duration(minutes: 12),
      workedTotal: const Duration(hours: 25, minutes: 30),
      overtimeDays: 1,
      toCheckDays: toCheck,
      notCalculatedDays: notCalculated,
    );

WorkTimeDay fakeDay(int n, DateTime day, DayState state) => WorkTimeDay(
      employeeId: 'emp$n',
      workDate: day,
      state: state,
      worked: state == DayState.present ? const Duration(hours: 8, minutes: 30) : Duration.zero,
      late: Duration.zero,
      overtime: false,
      absenceType: state == DayState.absent ? 'Maladie' : null,
      firstIn: state == DayState.present ? DateTime(day.year, day.month, day.day, 8) : null,
    );

/// Repository en mémoire : garde les appels pour les vérifier.
class FakeWorkTimeRepository implements WorkTimeRepository {
  FakeWorkTimeRepository({List<TimeEntryRow>? entries, WorkTimeReport? report})
      : entriesData = entries ?? [fakeEntry(1), fakeEntry(2, source: 'MANAGER_ASSISTED', status: 'PENDING')],
        reportData = report ??
            WorkTimeReport(summary: [fakeSummary(1, toCheck: 2), fakeSummary(2, notCalculated: 3)], days: [
              fakeDay(1, DateTime(2026, 11, 2), DayState.present),
              fakeDay(1, DateTime(2026, 11, 3), DayState.absent),
            ]);

  final List<TimeEntryRow> entriesData;
  final WorkTimeReport reportData;
  final List<({Period period, WorkTimeFilters filters, int offset})> entryCalls = [];
  final List<({Period period, WorkTimeFilters filters})> reportCalls = [];
  final List<({Period period, List<String>? employeeIds})> recalcCalls = [];
  final List<({Period period, WorkTimeFilters filters, ExportFormat format})> exportCalls = [];
  RecalcResult recalcResult = const RecalcResult(recalculated: 12, skippedValidated: 2, failed: 1);
  Object? error;

  @override
  Future<Paged<TimeEntryRow>> entries(String accessToken,
      {required Period period, WorkTimeFilters filters = const WorkTimeFilters(), int limit = 50, int offset = 0}) async {
    entryCalls.add((period: period, filters: filters, offset: offset));
    if (error != null) throw error!;
    return Paged(items: entriesData.skip(offset).take(limit).toList(), total: entriesData.length);
  }

  @override
  Future<WorkTimeReport> report(String accessToken,
      {required Period period, WorkTimeFilters filters = const WorkTimeFilters()}) async {
    reportCalls.add((period: period, filters: filters));
    if (error != null) throw error!;
    return reportData;
  }

  @override
  Future<RecalcResult> recalculate(String accessToken, {required Period period, List<String>? employeeIds}) async {
    recalcCalls.add((period: period, employeeIds: employeeIds));
    if (error != null) throw error!;
    return recalcResult;
  }

  @override
  Future<Uint8List> export(String accessToken,
      {required Period period, WorkTimeFilters filters = const WorkTimeFilters(), required ExportFormat format}) async {
    exportCalls.add((period: period, filters: filters, format: format));
    if (error != null) throw error!;
    return Uint8List.fromList([1, 2, 3]);
  }
}

final periodError = ApiException('La période ne peut pas dépasser 62 jours.', status: 422, code: 'PERIOD_TOO_LONG');
