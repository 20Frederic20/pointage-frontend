import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('a failed decision returns the message and keeps the list', () async {
    await controller().refresh();
    repo.decisionError = alreadyDecided();
    expect(await controller().validate('an1'), 'Cette anomalie a déjà été traitée.');
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
