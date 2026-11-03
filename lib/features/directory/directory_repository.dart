import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'directory_model.dart';

/// Routes `/directories` et `/sites` du backend. Les écritures sont réservées à l'ADMIN.
class DirectoryRepository {
  DirectoryRepository(this._api);
  final ApiClient _api;

  /// Le backend sert au plus 200 annuaires par page.
  static const pageSize = 200;

  Future<Paged<Directory>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    final data =
        await _api.get('/directories', accessToken: accessToken, query: {'limit': '$limit', 'offset': '$offset'});
    return Paged.fromJson(data as Map<String, dynamic>, Directory.fromJson);
  }

  /// Tous les annuaires, page après page.
  Future<List<Directory>> all(String accessToken) async {
    final all = <Directory>[];
    while (true) {
      final page = await list(accessToken, limit: pageSize, offset: all.length);
      all.addAll(page.items);
      if (page.items.isEmpty || all.length >= page.total) return all;
    }
  }

  /// Site principal d'abord, puis les annexes par nom (désactivés compris).
  Future<List<Site>> sites(String accessToken, String directoryId) async {
    final data = await _api.get('/directories/$directoryId/sites', accessToken: accessToken);
    return (data as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Directory> create(String accessToken, {required String name, required String code, String? parentDirectoryId}) async =>
      Directory.fromJson(await _api.post(
          '/directories', {'name': name, 'code': code, 'parent_directory_id': ?parentDirectoryId},
          accessToken: accessToken));

  Future<Directory> update(String accessToken, String id, {String? name, String? code}) async =>
      Directory.fromJson(await _api.patch('/directories/$id', {'name': ?name, 'code': ?code}, accessToken: accessToken));

  Future<Directory> setActive(String accessToken, String id, bool active) async => Directory.fromJson(
      await _api.post('/directories/$id/${active ? 'activate' : 'deactivate'}', {}, accessToken: accessToken));

  Future<Site> createSite(String accessToken,
          {required String directoryId,
          required String name,
          required double latitude,
          required double longitude,
          String? address}) async =>
      Site.fromJson(await _api.post('/sites', {
        'directory_id': directoryId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': ?address,
      }, accessToken: accessToken));

  Future<Site> updateSite(String accessToken, String id,
          {String? name, String? address, double? latitude, double? longitude}) async =>
      Site.fromJson(await _api.patch('/sites/$id', {
        'name': ?name,
        'address': ?address,
        'latitude': ?latitude,
        'longitude': ?longitude,
      }, accessToken: accessToken));

  Future<Site> setSiteActive(String accessToken, String id, bool active) async =>
      Site.fromJson(await _api.post('/sites/$id/${active ? 'activate' : 'deactivate'}', {}, accessToken: accessToken));

  Future<Site> makePrincipal(String accessToken, String id) async =>
      Site.fromJson(await _api.post('/sites/$id/make-principal', {}, accessToken: accessToken));
}

final directoryRepositoryProvider = Provider((ref) => DirectoryRepository(ref.watch(apiClientProvider)));
