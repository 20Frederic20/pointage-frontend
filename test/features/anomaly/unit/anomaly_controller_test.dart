import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/anomaly/anomaly_controller.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';

import '../../../helpers/anomaly_fakes.dart';
import '../../../helpers/fakes.dart';

void main() {
  late FakeAnomalyRepository repo;
  late ProviderContainer container;
  AnomalyController controller() => container.read(anomalyControllerProvider.notifier);
  AnomalyState state() => container.read(anomalyControllerProvider);

  setUp(() {
    repo = FakeAnomalyRepository();
    container = ProviderContainer.test(
      overrides: [fakeSession(), anomalyRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
  });

  test('loads OPEN by default', () async {
    await controller().refresh();
    expect(repo.listStatuses, ['OPEN']);
    expect(state().status, 'OPEN');
    expect(state().items, hasLength(3));
  });

  test('reject refreshes and the item leaves the OPEN list', () async {
    await controller().refresh();
    final error = await controller().reject('an2', 'Photo floue');
    expect(error, isNull);
    expect(repo.decisions.single, (id: 'an2', decision: 'reject', comment: 'Photo floue'));
    expect(state().items.map((a) => a.id), ['an1', 'an3']);
    expect(state().total, 2);
  });

  test('validate refreshes and the item leaves the OPEN list', () async {
    await controller().refresh();
    expect(await controller().validate('an1'), isNull);
    expect(state().items.map((a) => a.id), ['an2', 'an3']);
  });

  test('success removes the row even when the refetch still returns it OPEN', () async {
    await controller().refresh();
    repo.readModelLags = true;
    expect(await controller().validate('an1'), isNull);
    expect(repo.listStatuses, hasLength(2)); // refetched
    expect(state().items.map((a) => a.id), ['an2', 'an3']);
    expect(state().total, 2);
  });

  test('with no status filter, a decided row is patched with the server answer', () async {
    await controller().refresh();
    await controller().setStatus(null);
    repo.readModelLags = true;
    expect(await controller().reject('an2', 'non'), isNull);
    expect(state().items.map((a) => (a.id, a.status)), [('an1', 'OPEN'), ('an2', 'REJECTED'), ('an3', 'OPEN')]);
    expect(state().total, 3);
  });

  test('a 409 returns the message and refreshes the list', () async {
    await controller().refresh();
    repo.decisionError = alreadyDecided();
    expect(await controller().validate('an1'), 'Cette anomalie a déjà été traitée.');
    expect(repo.listStatuses, hasLength(2));
  });

  test('a 404 refreshes the list too', () async {
    await controller().refresh();
    repo.decisionError = ApiException('introuvable', status: 404);
    expect(await controller().validate('an1'), 'Anomalie introuvable.');
    expect(repo.listStatuses, hasLength(2));
  });

  test('a network failure returns the message and keeps the list without refetching', () async {
    await controller().refresh();
    repo.decisionError = Exception('timeout');
    expect(await controller().validate('an1'), 'Connexion au serveur impossible, réessayez.');
    expect(state().items, hasLength(3));
    expect(repo.listStatuses, hasLength(1));
  });

  test('setStatus changes the filter and reloads from page 0', () async {
    await controller().refresh();
    await controller().reject('an1', 'non');
    await controller().setStatus('REJECTED');
    expect(repo.listStatuses.last, 'REJECTED');
    expect(state().items.map((a) => a.id), ['an1']);
    await controller().setStatus(null);
    expect(repo.listStatuses.last, isNull);
    expect(state().items, hasLength(3));
  });
}
