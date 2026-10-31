/// Annuaire (`DirectoryResponse`) : une entité à laquelle les employés sont affectés.
class Directory {
  const Directory({required this.id, required this.name, required this.code, this.parentDirectoryId});

  final String id;
  final String name;
  final String code;

  /// null : un annuaire racine, c'est-à-dire une entreprise ; sinon un de ses services.
  final String? parentDirectoryId;

  bool get isCompany => parentDirectoryId == null;

  factory Directory.fromJson(Map<String, dynamic> j) => Directory(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        parentDirectoryId: j['parentDirectoryId'] as String?,
      );
}

/// Site d'un annuaire (`SiteResponse`), réduit à ce dont le formulaire a besoin.
class Site {
  const Site({required this.id, required this.name});

  final String id;
  final String name;

  factory Site.fromJson(Map<String, dynamic> j) => Site(id: j['id'] as String, name: j['name'] as String);
}
