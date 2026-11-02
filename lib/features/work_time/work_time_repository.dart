import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'period.dart';
import 'work_time_model.dart';

/// Routes `/time-entries` (liste) et `/work-time` du backend.
class WorkTimeRepository {
  WorkTimeRepository(this._api);
  final ApiClient _api;

  Future<Paged<TimeEntryRow>> entries(String accessToken,
      {required Period period, WorkTimeFilters filters = const WorkTimeFilters(), int limit = 50, int offset = 0}) async {
    final data = await _api.get('/time-entries', accessToken: accessToken, query: {
      ...period.query,
      ...filters.query,
      'limit': '$limit',
      'offset': '$offset',
    });
    return Paged.fromJson(data as Map<String, dynamic>, TimeEntryRow.fromJson);
  }

  Future<WorkTimeReport> report(String accessToken,
      {required Period period, WorkTimeFilters filters = const WorkTimeFilters()}) async {
    final data = await _api.get('/work-time', accessToken: accessToken, query: {...period.query, ...filters.query});
    return WorkTimeReport.fromJson(data as Map<String, dynamic>);
  }

  Future<RecalcResult> recalculate(String accessToken, {required Period period, List<String>? employeeIds}) async =>
      RecalcResult.fromJson(await _api.post(
          '/work-time/recalculate',
          {...period.query, if (employeeIds != null && employeeIds.isNotEmpty) 'employeeIds': employeeIds},
          accessToken: accessToken,
          timeout: ApiClient.longTimeout));

  Future<Uint8List> export(String accessToken,
          {required Period period, WorkTimeFilters filters = const WorkTimeFilters(), required ExportFormat format}) =>
      _api.getBytes('/work-time/export',
          accessToken: accessToken,
          query: {...period.query, ...filters.query, 'format': format.name},
          timeout: ApiClient.longTimeout);
}

final workTimeRepositoryProvider = Provider((ref) => WorkTimeRepository(ref.watch(apiClientProvider)));
