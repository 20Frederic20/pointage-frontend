import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/user/user_controller.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('allUsersProvider lists the accounts', () async {
    final container = ProviderContainer.test(
      overrides: [fakeSession(), userRepositoryProvider.overrideWithValue(FakeUserRepository())],
      retry: (_, _) => null,
    );
    final sub = container.listen(allUsersProvider, (_, _) {});
    expect((await container.read(allUsersProvider.future)).single.id, 'usr1');
    sub.close();
  });
}
