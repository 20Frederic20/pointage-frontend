import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/paged.dart';
import 'package:pointage/features/directory/directory_model.dart';
import 'package:pointage/features/directory/directory_repository.dart';

/// Dépôt d'annuaires en mémoire : les actions changent l'état et sont enregistrées.
class FakeDirectoryAdminRepository implements DirectoryRepository {
  FakeDirectoryAdminRepository()
      : directories = [
          const Directory(id: 'a', name: 'Société A', code: 'SA'),
          const Directory(id: 'n', name: 'Agence Nord', code: 'SA-N', parentDirectoryId: 'a'),
          const Directory(id: 'b', name: 'Société B', code: 'SB'),
        ],
        sitesByDirectory = {
          'a': [
            const Site(id: 's1', name: 'Siège A', directoryId: 'a', latitude: 6.36, longitude: 2.41, isPrincipal: true),
            const Site(id: 's2', name: 'Annexe A', directoryId: 'a', latitude: 6.37, longitude: 2.42),
          ],
          'n': [const Site(id: 's3', name: 'Agence Nord', directoryId: 'n', latitude: 6.5, longitude: 2.6, isPrincipal: true)],
        };

  final List<Directory> directories;
  final Map<String, List<Site>> sitesByDirectory;
  final List<String> calls = [];
  final List<Map<String, Object?>> createdSites = [];
  int _n = 0;

  @override
  Future<List<Directory>> all(String accessToken) async => List.of(directories);

  @override
  Future<Paged<Directory>> list(String accessToken, {int limit = 100, int offset = 0}) async =>
      Paged(items: directories, total: directories.length);

  @override
  Future<List<Site>> sites(String accessToken, String directoryId) async => List.of(sitesByDirectory[directoryId] ?? []);

  @override
  Future<Directory> create(String accessToken, {required String name, required String code, String? parentDirectoryId}) async {
    calls.add('create $name');
    final d = Directory(id: 'new${_n++}', name: name, code: code, parentDirectoryId: parentDirectoryId);
    directories.add(d);
    return d;
  }

  @override
  Future<Directory> update(String accessToken, String id, {String? name, String? code}) async {
    calls.add('update $id');
    final i = directories.indexWhere((d) => d.id == id);
    return directories[i] = directories[i].copyWith(name: name, code: code);
  }

  @override
  Future<Directory> setActive(String accessToken, String id, bool active) async {
    calls.add('${active ? 'activate' : 'deactivate'} $id');
    final i = directories.indexWhere((d) => d.id == id);
    return directories[i] = directories[i].copyWith(active: active);
  }

  @override
  Future<Site> createSite(String accessToken,
      {required String directoryId, required String name, required double latitude, required double longitude, String? address}) async {
    createdSites.add({'directoryId': directoryId, 'name': name, 'latitude': latitude, 'longitude': longitude, 'address': address});
    final s = Site(id: 'site${_n++}', name: name, directoryId: directoryId, latitude: latitude, longitude: longitude);
    sitesByDirectory.putIfAbsent(directoryId, () => []).add(s);
    return s;
  }

  @override
  Future<Site> updateSite(String accessToken, String id, {String? name, String? address, double? latitude, double? longitude}) async {
    calls.add('updateSite $id');
    throw UnimplementedError();
  }

  @override
  Future<Site> setSiteActive(String accessToken, String id, bool active) async {
    calls.add('${active ? 'activateSite' : 'deactivateSite'} $id');
    for (final list in sitesByDirectory.values) {
      final i = list.indexWhere((s) => s.id == id);
      if (i < 0) continue;
      if (list[i].isPrincipal && !active) {
        throw ApiException(
            "Le site principal ne peut pas être désactivé : rendez d'abord un autre site principal.",
            status: 409, code: 'PRINCIPAL_SITE_CANNOT_BE_DEACTIVATED');
      }
      return list[i] = list[i].copyWith(active: active);
    }
    throw ApiException('Élément introuvable.', status: 404);
  }

  @override
  Future<Site> makePrincipal(String accessToken, String id) async {
    calls.add('makePrincipal $id');
    throw UnimplementedError();
  }
}
