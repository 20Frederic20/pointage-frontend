/// Une page de résultats du backend : `{items, total}`.
/// (`Page` est déjà une classe de Flutter, d'où le nom.)
class Paged<T> {
  const Paged({required this.items, required this.total});

  final List<T> items;

  /// Nombre total d'éléments correspondant à la requête, toutes pages confondues.
  final int total;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => Paged(
        items: (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
        total: j['total'] as int,
      );
}
