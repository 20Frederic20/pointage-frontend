import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/punch/punch_repository.dart';
import 'package:pointage/features/punch/punch_screen.dart';
import 'package:pointage/features/work_time/period.dart';
import 'package:pointage/features/work_time/screens/my_time_entries_screen.dart';
import 'package:pointage/features/work_time/work_time_model.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

import '../../../helpers/assisted_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';
import '../../../helpers/work_time_fakes.dart';

void main() {
  late FakeWorkTimeRepository repo;
  setUp(() => repo = FakeWorkTimeRepository(
        entries: [
          fakeEntry(1),
          fakeEntry(2, source: 'ASSISTED', status: 'PENDING'),
          TimeEntryRow(id: 't9', employeeId: 'emp1', employeeNumber: 'EMP0000001', entryType: 'IN',
              occuredAt: DateTime(2026, 11, 1, 7, 55), source: 'MOBILE', validationStatus: 'REJECTED'),
        ],
        report: WorkTimeReport(summary: [fakeSummary(1)], days: const []),
      ));

  List<Override> overrides() => [fakeSession(role: 'EMPLOYEE'), workTimeRepositoryProvider.overrideWithValue(repo)];

  testWidgets('the totals come from the API and the entries are grouped by day', (tester) async {
    await pumpAtWidth(tester, 360, const MyTimeEntriesScreen(), height: 740, overrides: overrides());
    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(repo.entryCalls.single.period, Period.today());
    expect(repo.entryCalls.single.filters.query, isEmpty); // le backend restreint à la fiche de la session
    expect(repo.reportCalls.single.filters.query, isEmpty);
    for (final label in ['Heures travaillées', 'Jours présents', 'Retards', 'Heures supp.']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('25:30'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // présences : du rapport, pas un compte local
    expect(find.text('Dimanche 01/11/2026'), findsOneWidget);
    expect(find.text('Lundi 02/11/2026'), findsOneWidget);
    expect(find.text('Entrée · 08:01'), findsOneWidget);
    expect(find.text('Sortie · 08:02'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Rejeté'), findsOneWidget);
    expect(find.text('Compté'), findsNothing); // l'état normal n'est pas signalé
    expect(tester.takeException(), isNull);
  });

  testWidgets('no entry: an empty message, zero totals', (tester) async {
    repo = FakeWorkTimeRepository(entries: [], report: const WorkTimeReport(summary: [], days: []));
    await pumpAtWidth(tester, 360, const MyTimeEntriesScreen(), height: 740, overrides: overrides());
    expect(find.text('Aucun pointage sur la période'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('an error offers to retry', (tester) async {
    repo.error = periodError;
    await pumpAtWidth(tester, 360, const MyTimeEntriesScreen(), height: 740, overrides: overrides());
    expect(find.text('La période ne peut pas dépasser 62 jours.'), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('25:30'), findsOneWidget);
  });

  testWidgets('PunchScreen shows « Mes pointages » to an employee and opens it', (tester) async {
    await pumpAtWidth(tester, 400, const PunchScreen(),
        overrides: [...overrides(), punchRepositoryProvider.overrideWithValue(FakePunchRepository())], settle: false);
    expect(find.byTooltip('Mes pointages'), findsOneWidget);
    await tester.tap(find.byTooltip('Mes pointages'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MyTimeEntriesScreen), findsOneWidget);
  });
}
