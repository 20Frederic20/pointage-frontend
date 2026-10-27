import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'anomaly_model.dart';

/// Routes `/anomalies` du backend.
class AnomalyRepository {
  AnomalyRepository(this._api);
  final ApiClient _api;

  Future<Paged<Anomaly>> list(String accessToken, {String? status, int limit = 20, int offset = 0}) async {
    final data = await _api.get('/anomalies', accessToken: accessToken, query: {
      'status': ?status,
      'limit': '$limit',
      'offset': '$offset',
    });
    return Paged.fromJson(data as Map<String, dynamic>, Anomaly.fromJson);
  }

  Future<Uint8List> photo(String accessToken, String id) => _api.getBytes('/anomalies/$id/photo', accessToken: accessToken);

  Future<Anomaly> validate(String accessToken, String id, {String? comment}) async => Anomaly.fromJson(
      await _api.post('/anomalies/$id/validate', {if (comment != null && comment.isNotEmpty) 'comment': comment},
          accessToken: accessToken));

  Future<Anomaly> reject(String accessToken, String id, String comment) async =>
      Anomaly.fromJson(await _api.post('/anomalies/$id/reject', {'comment': comment}, accessToken: accessToken));
}

final anomalyRepositoryProvider = Provider((ref) => AnomalyRepository(ref.watch(apiClientProvider)));
