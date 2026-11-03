import 'directory_model.dart';

/// Un nœud de l'arbre des annuaires : l'annuaire, ses services et ses sites.
class DirectoryNode {
  DirectoryNode({required this.directory, required this.children, required this.sites, this.blockedBy});

  final Directory directory;
  final List<DirectoryNode> children;
  final List<Site> sites;

  /// L'ancêtre désactivé qui le bloque (le plus haut) ; null s'il n'est bloqué que par lui-même ou pas du tout.
  final Directory? blockedBy;

  /// Désactivé lui-même ou sous un annuaire désactivé : plus de pointage ni de nouvelle affectation.
  bool get blocked => !directory.active || blockedBy != null;
}

/// Entreprises (racines) triées par nom, services imbriqués et triés, sites rattachés.
/// Un annuaire dont le parent est inconnu apparaît comme une racine.
List<DirectoryNode> buildDirectoryTree(List<Directory> directories, Map<String, List<Site>> sitesByDirectory) {
  final ids = {for (final d in directories) d.id};
  final byParent = <String?, List<Directory>>{};
  for (final d in directories) {
    final parent = d.parentDirectoryId != null && ids.contains(d.parentDirectoryId) ? d.parentDirectoryId : null;
    byParent.putIfAbsent(parent, () => []).add(d);
  }
  List<DirectoryNode> build(String? parentId, Directory? blocker, Set<String> seen) {
    final items = [...?byParent[parentId]]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (final d in items)
        if (seen.add(d.id))
          DirectoryNode(
            directory: d,
            blockedBy: blocker,
            sites: sitesByDirectory[d.id] ?? const [],
            children: build(d.id, blocker ?? (d.active ? null : d), seen),
          ),
    ];
  }

  return build(null, null, {});
}

/// Le site est désactivé, ou son annuaire (ou un ancêtre) l'est.
bool isSiteBlocked(Site site, DirectoryNode owner) => !site.active || owner.blocked;

DirectoryNode? findNode(List<DirectoryNode> nodes, String directoryId) {
  for (final node in nodes) {
    if (node.directory.id == directoryId) return node;
    if (findNode(node.children, directoryId) case final found?) return found;
  }
  return null;
}

/// Annuaires où l'on peut encore affecter : ni désactivés, ni sous un annuaire désactivé (ordre d'origine).
List<Directory> assignableDirectories(List<Directory> all) {
  final blocked = <String>{};
  void walk(List<DirectoryNode> nodes) {
    for (final node in nodes) {
      if (node.blocked) blocked.add(node.directory.id);
      walk(node.children);
    }
  }

  walk(buildDirectoryTree(all, const {}));
  return [for (final d in all) if (!blocked.contains(d.id)) d];
}

/// Sites où l'on peut encore affecter : les sites actifs.
List<Site> assignableSites(List<Site> sites) => [for (final s in sites) if (s.active) s];
