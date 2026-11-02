import 'period.dart';

DateTime? _instant(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
Duration _minutes(Object? v) => Duration(minutes: (v as num?)?.toInt() ?? 0);

String _name(String? first, String? last, String fallback) {
  final name = [first, last].whereType<String>().where((p) => p.isNotEmpty).join(' ');
  return name.isEmpty ? fallback : name;
}

/// Filtres communs aux pointages, au temps de travail et aux exports.
class WorkTimeFilters {
  const WorkTimeFilters({this.employeeId, this.companyDirectoryId, this.siteId});

  final String? employeeId;
  final String? companyDirectoryId;
  final String? siteId;

  Map<String, String> get query => {
        'employee_id': ?employeeId,
        'company_directory_id': ?companyDirectoryId,
        'site_id': ?siteId,
      };
}

/// Une ligne de `GET /time-entries`.
class TimeEntryRow {
  const TimeEntryRow({
    required this.id,
    required this.employeeId,
    required this.employeeNumber,
    required this.entryType,
    required this.occuredAt,
    required this.source,
    required this.validationStatus,
    this.firstName,
    this.lastName,
    this.companyName,
    this.siteName,
    this.assistedByName,
  });

  final String id;
  final String employeeId;
  final String employeeNumber;
  final String? firstName;
  final String? lastName;
  final String? companyName;
  final String? siteName;
  final String entryType;
  final DateTime occuredAt;
  final String source;
  final String validationStatus;
  final String? assistedByName;

  bool get isIn => entryType == 'IN';
  String get displayName => _name(firstName, lastName, employeeNumber);

  factory TimeEntryRow.fromJson(Map<String, dynamic> j) => TimeEntryRow(
        id: j['id'] as String,
        employeeId: j['employeeId'] as String,
        employeeNumber: j['employeeNumber'] as String,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        companyName: j['companyName'] as String?,
        siteName: j['siteName'] as String?,
        entryType: j['entryType'] as String,
        occuredAt: _instant(j['occuredAt'])!,
        source: j['source'] as String,
        validationStatus: j['validationStatus'] as String,
        assistedByName: j['assistedByName'] as String?,
      );
}

/// État d'un employé sur une journée.
enum DayState {
  present('Présent'),
  toCheck('À vérifier'),
  notCalculated('Non calculé'),
  absent('Absent'),
  notYetArrived('Pas encore arrivé');

  const DayState(this.label);
  final String label;

  static DayState parse(String v) => switch (v) {
        'PRESENT' => present,
        'TO_CHECK' => toCheck,
        'ABSENT' => absent,
        'NOT_YET_ARRIVED' => notYetArrived,
        _ => notCalculated,
      };
}

class WorkTimeSummaryRow {
  const WorkTimeSummaryRow({
    required this.employeeId,
    required this.employeeNumber,
    this.firstName,
    this.lastName,
    this.companyName,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.lateTotal,
    required this.workedTotal,
    required this.overtimeDays,
    required this.toCheckDays,
    required this.notCalculatedDays,
  });

  final String employeeId;
  final String employeeNumber;
  final String? firstName;
  final String? lastName;
  final String? companyName;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final Duration lateTotal;
  final Duration workedTotal;
  final int overtimeDays;
  final int toCheckDays;
  final int notCalculatedDays;

  String get displayName => _name(firstName, lastName, employeeNumber);

  factory WorkTimeSummaryRow.fromJson(Map<String, dynamic> j) => WorkTimeSummaryRow(
        employeeId: j['employeeId'] as String,
        employeeNumber: j['employeeNumber'] as String,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        companyName: j['companyName'] as String?,
        presentDays: j['presentDays'] as int,
        absentDays: j['absentDays'] as int,
        lateDays: j['lateDays'] as int,
        lateTotal: _minutes(j['lateTotalMinutes']),
        workedTotal: _minutes(j['workedTotalMinutes']),
        overtimeDays: j['overtimeDays'] as int,
        toCheckDays: j['toCheckDays'] as int,
        notCalculatedDays: j['notCalculatedDays'] as int,
      );
}

class WorkTimeDay {
  const WorkTimeDay({
    required this.employeeId,
    required this.workDate,
    required this.state,
    required this.worked,
    required this.late,
    required this.overtime,
    this.absenceType,
    this.firstIn,
    this.lastOut,
  });

  final String employeeId;
  final DateTime workDate;
  final DayState state;
  final Duration worked;
  final Duration late;
  final bool overtime;
  final String? absenceType;
  final DateTime? firstIn;
  final DateTime? lastOut;

  factory WorkTimeDay.fromJson(Map<String, dynamic> j) => WorkTimeDay(
        employeeId: j['employeeId'] as String,
        workDate: DateTime.parse(j['workDate'] as String),
        state: DayState.parse(j['state'] as String),
        worked: _minutes(j['workedMinutes']),
        late: _minutes(j['lateMinutes']),
        overtime: j['overtime'] as bool? ?? false,
        absenceType: j['absenceType'] as String?,
        firstIn: _instant(j['firstIn']),
        lastOut: _instant(j['lastOut']),
      );
}

class WorkTimeReport {
  const WorkTimeReport({required this.summary, required this.days});

  final List<WorkTimeSummaryRow> summary;
  final List<WorkTimeDay> days;

  factory WorkTimeReport.fromJson(Map<String, dynamic> j) => WorkTimeReport(
        summary: (j['summary'] as List).map((e) => WorkTimeSummaryRow.fromJson(e as Map<String, dynamic>)).toList(),
        days: (j['days'] as List).map((e) => WorkTimeDay.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class RecalcResult {
  const RecalcResult({required this.recalculated, required this.skippedValidated, required this.failed});

  final int recalculated;
  final int skippedValidated;
  final int failed;

  factory RecalcResult.fromJson(Map<String, dynamic> j) => RecalcResult(
        recalculated: j['recalculated'] as int,
        skippedValidated: j['skippedValidated'] as int,
        failed: j['failed'] as int,
      );
}

enum ExportFormat {
  xlsx('Excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('PDF', 'application/pdf'),
  csv('CSV', 'text/csv');

  const ExportFormat(this.label, this.mimeType);
  final String label;
  final String mimeType;

  String filename(Period period) => 'temps-de-travail_${period.query['from']}_${period.query['to']}.$name';
}
