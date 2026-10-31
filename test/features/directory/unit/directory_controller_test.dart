import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/directory/directory_controller.dart';
import 'package:pointage/features/directory/directory_repository.dart';

import '../../../helpers/fakes.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer.test(
        overrides: [fakeSession(), directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository())],
        retry: (_, _) => null,
      ));

  test('allDirectoriesProvider lists the directories', () async {
    final sub = container.listen(allDirectoriesProvider, (_, _) {});
    expect((await container.read(allDirectoriesProvider.future)).single.code, 'DG');
    sub.close();
  });

  test('directorySitesProvider lists the sites of one directory', () async {
    final sub = container.listen(directorySitesProvider('dir1'), (_, _) {});
    expect((await container.read(directorySitesProvider('dir1').future)).single.name, 'Siège Cotonou');
    sub.close();
  });
}
