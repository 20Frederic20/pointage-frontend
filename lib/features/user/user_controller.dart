import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import 'user_model.dart';
import 'user_repository.dart';

/// Comptes proposés dans le formulaire de création d'employé (les 100 premiers).
final allUsersProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) async => (await ref.read(userRepositoryProvider).list(await requireAccessToken(ref))).items,
  retry: (_, _) => null,
);
