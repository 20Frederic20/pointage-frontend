import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/session_provider.dart';
import 'directory_model.dart';
import 'directory_repository.dart';
import 'directory_tree.dart';

String directoryErrorMessage(Object e) => switch (e) {
      ApiException(:final message) => message,
      _ => 'Connexion au serveur impossible, réessayez.',
    };

/// Ce qui est ouvert dans le panneau de détail : un annuaire ou un site.
typedef DirectorySelection = ({bool isSite, String id});

/// Arbre des annuaires de l'écran « Annuaires » (ADMIN) et ses actions.
class DirectoryAdminController extends AsyncNotifier<List<DirectoryNode>> {
  @override
  Future<List<DirectoryNode>> build() async {
    ref.watch(sessionProvider.select((s) => s.value?.identifier));
    return _load();
  }

  Future<List<DirectoryNode>> _load() async {
    final token = await requireAccessToken(ref);
    final repo = ref.read(directoryRepositoryProvider);
    final directories = await repo.all(token);
    final sites = await Future.wait(directories.map((d) => repo.sites(token, d.id)));
    return buildDirectoryTree(directories, {for (var i = 0; i < directories.length; i++) directories[i].id: sites[i]});
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(_load);
    if (ref.mounted) state = next;
  }

  /// Lance [action], recharge l'arbre ; renvoie le message d'erreur, ou null en cas de succès.
  Future<String?> _run<T>(Future<T> Function(DirectoryRepository repo, String token) action,
      {void Function(T result)? onDone}) async {
    try {
      final result = await action(ref.read(directoryRepositoryProvider), await requireAccessToken(ref));
      onDone?.call(result);
      await reload();
      return null;
    } catch (e) {
      return directoryErrorMessage(e);
    }
  }

  void _select(DirectorySelection selection) => ref.read(directorySelectionProvider.notifier).select(selection);

  Future<String?> createDirectory({required String name, required String code, String? parentId}) => _run(
      (repo, token) => repo.create(token, name: name, code: code, parentDirectoryId: parentId),
      onDone: (Directory d) => _select((isSite: false, id: d.id)));

  Future<String?> updateDirectory(String id, {required String name, required String code}) =>
      _run((repo, token) => repo.update(token, id, name: name, code: code));

  Future<String?> setDirectoryActive(String id, bool active) => _run((repo, token) => repo.setActive(token, id, active));

  Future<String?> createSite(String directoryId,
          {required String name, required double latitude, required double longitude, String? address}) =>
      _run(
          (repo, token) => repo.createSite(token,
              directoryId: directoryId, name: name, latitude: latitude, longitude: longitude, address: address),
          onDone: (Site s) => _select((isSite: true, id: s.id)));

  Future<String?> updateSite(String id,
          {required String name, required double latitude, required double longitude, String? address}) =>
      _run((repo, token) => repo.updateSite(token, id, name: name, address: address, latitude: latitude, longitude: longitude));

  Future<String?> setSiteActive(String id, bool active) => _run((repo, token) => repo.setSiteActive(token, id, active));

  Future<String?> makePrincipal(String id) => _run((repo, token) => repo.makePrincipal(token, id));
}

final directoryAdminControllerProvider =
    AsyncNotifierProvider<DirectoryAdminController, List<DirectoryNode>>(DirectoryAdminController.new);

class DirectorySelectionNotifier extends Notifier<DirectorySelection?> {
  @override
  DirectorySelection? build() => null;

  void select(DirectorySelection? selection) => state = selection;
}

final directorySelectionProvider =
    NotifierProvider<DirectorySelectionNotifier, DirectorySelection?>(DirectorySelectionNotifier.new);

/// Le site [siteId] et le nœud de son annuaire, s'il est dans l'arbre.
(Site, DirectoryNode)? findSite(List<DirectoryNode> nodes, String siteId) {
  for (final node in nodes) {
    for (final site in node.sites) {
      if (site.id == siteId) return (site, node);
    }
    if (findSite(node.children, siteId) case final found?) return found;
  }
  return null;
}
