import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import 'directory_model.dart';
import 'directory_repository.dart';

/// Annuaires proposés dans le formulaire de création d'employé (les 100 premiers).
final allDirectoriesProvider = FutureProvider.autoDispose<List<Directory>>(
  (ref) async => (await ref.read(directoryRepositoryProvider).list(await requireAccessToken(ref))).items,
  retry: (_, _) => null,
);

/// Sites d'un annuaire, site principal en premier.
final directorySitesProvider = FutureProvider.autoDispose.family<List<Site>, String>(
  (ref, directoryId) async => ref.read(directoryRepositoryProvider).sites(await requireAccessToken(ref), directoryId),
  retry: (_, _) => null,
);
