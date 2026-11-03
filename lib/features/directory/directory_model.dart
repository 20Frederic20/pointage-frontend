/// Annuaire (`DirectoryResponse`) : une entité à laquelle les employés sont affectés.
class Directory {
  const Directory({
    required this.id,
    required this.name,
    required this.code,
    this.parentDirectoryId,
    this.active = true,
  });

  final String id;
  final String name;
  final String code;

  /// null : un annuaire racine, c'est-à-dire une entreprise ; sinon un de ses services.
  final String? parentDirectoryId;

  /// Son propre état ; un parent désactivé le bloque sans le changer.
  final bool active;

  bool get isCompany => parentDirectoryId == null;

  Directory copyWith({String? name, String? code, bool? active}) => Directory(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        parentDirectoryId: parentDirectoryId,
        active: active ?? this.active,
      );

  factory Directory.fromJson(Map<String, dynamic> j) => Directory(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        parentDirectoryId: j['parentDirectoryId'] as String?,
        active: j['active'] as bool? ?? true,
      );
}

/// Site d'un annuaire (`SiteResponse`) : un lieu où l'on pointe.
class Site {
  const Site({
    required this.id,
    required this.name,
    this.directoryId,
    this.latitude,
    this.longitude,
    this.address,
    this.isPrincipal = false,
    this.active = true,
  });

  final String id;
  final String name;
  final String? directoryId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isPrincipal;
  final bool active;

  bool get hasPosition => latitude != null && longitude != null;

  Site copyWith({bool? active}) => Site(
        id: id,
        name: name,
        directoryId: directoryId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        isPrincipal: isPrincipal,
        active: active ?? this.active,
      );

  factory Site.fromJson(Map<String, dynamic> j) {
    final location = j['location'] as Map<String, dynamic>?;
    return Site(
      id: j['id'] as String,
      name: j['name'] as String,
      directoryId: j['directoryId'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      address: j['address'] as String?,
      isPrincipal: j['kind'] == 'PRINCIPAL',
      active: j['active'] as bool? ?? true,
    );
  }
}
