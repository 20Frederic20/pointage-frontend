import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'directory_model.dart';

/// Routes `/directories` du backend.
class DirectoryRepository {
  DirectoryRepository(this._api);
  final ApiClient _api;

  Future<Paged<Directory>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    final data =
        await _api.get('/directories', accessToken: accessToken, query: {'limit': '$limit', 'offset': '$offset'});
    return Paged.fromJson(data as Map<String, dynamic>, Directory.fromJson);
  }

  /// Site principal d'abord, puis les annexes par nom.
  Future<List<Site>> sites(String accessToken, String directoryId) async {
    final data = await _api.get('/directories/$directoryId/sites', accessToken: accessToken);
    return (data as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final directoryRepositoryProvider = Provider((ref) => DirectoryRepository(ref.watch(apiClientProvider)));
