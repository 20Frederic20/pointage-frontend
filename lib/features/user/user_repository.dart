import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/paged.dart';
import 'user_model.dart';

/// Routes `/users` du backend.
class UserRepository {
  UserRepository(this._api);
  final ApiClient _api;

  Future<Paged<AppUser>> list(String accessToken, {int limit = 100, int offset = 0}) async {
    final data = await _api.get('/users', accessToken: accessToken, query: {'limit': '$limit', 'offset': '$offset'});
    return Paged.fromJson(data as Map<String, dynamic>, AppUser.fromJson);
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository(ref.watch(apiClientProvider)));
