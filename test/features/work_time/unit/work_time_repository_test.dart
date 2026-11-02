import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/work_time/period.dart';
import 'package:pointage/features/work_time/work_time_model.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

final _period = Period(DateTime(2026, 10, 1), DateTime(2026, 10, 7));
const _filters = WorkTimeFilters(companyDirectoryId: 'dir1');

void main() {
  late List<http.Request> sent;
  WorkTimeRepository repo(Object? body, {int status = 200, List<int>? bytes}) {
    sent = [];
    return WorkTimeRepository(ApiClient(MockClient((req) async {
      sent.add(req);
      return http.Response.bytes(bytes ?? utf8.encode(jsonEncode(body)), status);
    })));
  }

  test('entries: GET /time-entries with the period, the filters and the page', () async {
    final page = await repo({
      'items': [
        {'id': 't1', 'employeeId': 'emp1', 'employeeNumber': 'EMP0000001', 'firstName': 'Ana', 'lastName': 'Dossou',
         'companyName': 'Société R', 'siteName': 'Siège', 'entryType': 'IN', 'occuredAt': '2026-10-07T08:12:00Z',
         'source': 'MANAGER_ASSISTED', 'validationStatus': 'COUNTED', 'assistedByName': 'Paul Houngbo'},
      ],
      'total': 1,
    }).entries('tok', period: _period, filters: _filters, limit: 20, offset: 40);
    final req = sent.single;
    expect((req.method, req.url.path), ('GET', '/time-entries'));
    expect(req.url.queryParameters,
        {'from': '2026-10-01', 'to': '2026-10-07', 'company_directory_id': 'dir1', 'limit': '20', 'offset': '40'});
    expect(req.headers['Authorization'], 'Bearer tok');
    final e = page.items.single;
    expect((page.total, e.displayName, e.isIn, e.siteName, e.assistedByName), (1, 'Ana Dossou', true, 'Siège', 'Paul Houngbo'));
    expect(e.occuredAt, DateTime.utc(2026, 10, 7, 8, 12).toLocal());
  });

  test('report: GET /work-time, minutes become durations', () async {
    final report = await repo({
      'summary': [
        {'employeeId': 'emp1', 'employeeNumber': 'EMP0000001', 'firstName': 'Ana', 'lastName': 'Dossou',
         'companyName': 'Société R', 'presentDays': 4, 'absentDays': 1, 'lateDays': 2, 'lateTotalMinutes': 25,
         'workedTotalMinutes': 2010, 'overtimeDays': 1, 'toCheckDays': 0, 'notCalculatedDays': 1},
      ],
      'days': [
        {'employeeId': 'emp1', 'workDate': '2026-10-07', 'state': 'PRESENT', 'workedMinutes': 570, 'lateMinutes': 12,
         'overtime': true, 'absenceType': null, 'firstIn': '2026-10-07T08:12:00Z', 'lastOut': null},
        {'employeeId': 'emp1', 'workDate': '2026-10-06', 'state': 'ABSENT', 'workedMinutes': 0, 'lateMinutes': 0,
         'overtime': false, 'absenceType': 'Maladie', 'firstIn': null, 'lastOut': null},
      ],
    }).report('tok', period: _period, filters: const WorkTimeFilters(employeeId: 'emp1'));
    expect(sent.single.url.path, '/work-time');
    expect(sent.single.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-07', 'employee_id': 'emp1'});
    final s = report.summary.single;
    expect((s.displayName, s.presentDays, s.workedTotal, s.lateTotal, s.overtimeDays),
        ('Ana Dossou', 4, const Duration(hours: 33, minutes: 30), const Duration(minutes: 25), 1));
    final d = report.days.first;
    expect((d.workDate, d.state, d.worked, d.late, d.overtime),
        (DateTime(2026, 10, 7), DayState.present, const Duration(hours: 9, minutes: 30), const Duration(minutes: 12), true));
    expect(report.days.last.state.label, 'Absent');
    expect(report.days.last.absenceType, 'Maladie');
    expect(DayState.parse('WHATEVER'), DayState.notCalculated);
  });

  test('recalculate: POST /work-time/recalculate with the period and the employees', () async {
    final r = await repo({'recalculated': 12, 'skippedValidated': 2, 'failed': 1})
        .recalculate('tok', period: _period, employeeIds: ['emp1']);
    expect((sent.single.method, sent.single.url.path), ('POST', '/work-time/recalculate'));
    expect(jsonDecode(sent.single.body), {'from': '2026-10-01', 'to': '2026-10-07', 'employeeIds': ['emp1']});
    expect((r.recalculated, r.skippedValidated, r.failed), (12, 2, 1));
  });

  test('export: GET /work-time/export with the format, raw bytes back', () async {
    final bytes = await repo(null, bytes: [37, 80, 68, 70])
        .export('tok', period: _period, filters: _filters, format: ExportFormat.pdf);
    expect(sent.single.url.path, '/work-time/export');
    expect(sent.single.url.queryParameters,
        {'from': '2026-10-01', 'to': '2026-10-07', 'company_directory_id': 'dir1', 'format': 'pdf'});
    expect(bytes, [37, 80, 68, 70]);
    expect(ExportFormat.xlsx.filename(_period), 'temps-de-travail_2026-10-01_2026-10-07.xlsx');
    expect(ExportFormat.csv.mimeType, 'text/csv');
  });

  test('backend period errors are translated', () async {
    for (final (code, message) in [
      ('INVALID_PERIOD', 'La période est invalide.'),
      ('PERIOD_TOO_LONG', 'La période ne peut pas dépasser 62 jours.'),
      ('TOO_MANY_CALCULATIONS', "Trop de calculs demandés : réduisez la période ou le nombre d'employés."),
    ]) {
      await expectLater(repo({'code': code}, status: 422).report('tok', period: _period),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', message)));
    }
  });

  test('a failed export reports the translated error', () async {
    await expectLater(
        repo(null, status: 403, bytes: utf8.encode(jsonEncode({'code': 'ACCESS_DENIED'})))
            .export('tok', period: _period, format: ExportFormat.csv),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
  });
}
