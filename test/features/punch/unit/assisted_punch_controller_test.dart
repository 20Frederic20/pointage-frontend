import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/punch/assisted_punch_controller.dart';
import 'package:pointage/features/punch/punch_controller.dart';
import 'package:pointage/features/punch/punch_repository.dart';

import 'package:pointage/features/auth/session_provider.dart';

import '../../../helpers/assisted_fakes.dart';
import '../../../helpers/fakes.dart';

void main() {
  late FakePunchRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakePunchRepository();
    container = ProviderContainer(
      overrides: [
        fakeSession(),
        punchRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  AssistedPunchController ctrl() =>
      container.read(assistedPunchControllerProvider.notifier);
  AssistedPunchState state() => container.read(assistedPunchControllerProvider);

  Future<void> toSelfie() async {
    await container.read(sessionProvider.future);
    await ctrl().lookup('EMP0000002');
    ctrl().confirm();
    ctrl().setSelfie([1, 2, 3], 'image/jpeg');
  }

  test('starts on enterNumber', () {
    expect(state().step, AssistedStep.enterNumber);
  });

  test('lookup success moves to confirm', () async {
    await container.read(sessionProvider.future);
    await ctrl().lookup('EMP0000002');
    expect(state().step, AssistedStep.confirm);
    expect(state().colleague?.displayName, 'Ana Dossou');
  });

  test('lookup 404 gives Matricule introuvable.', () async {
    await container.read(sessionProvider.future);
    repo.lookupError = notFound();
    await ctrl().lookup('EMP0000099');
    expect(state().step, AssistedStep.error);
    expect(state().error, 'Matricule introuvable.');
  });

  test('lookup other API error shows its message', () async {
    await container.read(sessionProvider.future);
    repo.lookupError = ApiException(
      'Vous ne pouvez pas pointer pour vous-même.',
      status: 409,
      code: 'SELF_ASSISTED_PUNCH',
    );
    await ctrl().lookup('EMP0000001');
    expect(state().error, 'Vous ne pouvez pas pointer pour vous-même.');
  });

  test('send without selfie does nothing', () async {
    await container.read(sessionProvider.future);
    await ctrl().lookup('EMP0000002');
    ctrl().confirm();
    await ctrl().send();
    expect(repo.sent, isEmpty);
    expect(state().step, AssistedStep.selfie);
    expect(state().photo, isNull);
  });

  test('successful send moves to done with PENDING', () async {
    await toSelfie();
    await ctrl().send();
    expect(state().step, AssistedStep.done);
    expect(state().entry?.validationStatus, 'PENDING');
    expect(repo.sent.single.employeeNumber, 'EMP0000002');
  });

  test(
    'retry after a network error reuses the idempotency key; a new attempt gets a new one',
    () async {
      await toSelfie();
      repo.punchForError = Exception('network');
      await ctrl().send();
      expect(state().step, AssistedStep.error);
      expect(state().error, 'Pointage impossible, vérifiez la connexion.');
      repo.punchForError = null;
      await ctrl().send();
      expect(state().step, AssistedStep.done);
      expect(repo.keys, hasLength(2));
      expect(repo.keys[0], isNotNull);
      expect(repo.keys[0], repo.keys[1]);

      ctrl().reset();
      expect(state().step, AssistedStep.enterNumber);
      await toSelfie();
      await ctrl().send();
      expect(repo.keys[2], isNot(repo.keys[0]));
    },
  );

  test("does not touch the user's own PunchState", () async {
    await toSelfie();
    await ctrl().send();
    expect(container.read(punchControllerProvider).last, isNull);
  });
}
