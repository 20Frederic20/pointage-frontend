import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';
import 'package:pointage/features/anomaly/screens/anomaly_web_screen.dart';
import 'package:pointage/features/anomaly/widgets/anomaly_card.dart';
import 'package:pointage/features/anomaly/widgets/anomaly_detail_view.dart';

import '../../../helpers/anomaly_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeAnomalyRepository repo;
  setUp(() => repo = FakeAnomalyRepository(
      [fakeAnomaly(1, hasPhoto: true, siteName: 'Siège Cotonou'), fakeAnomaly(2), fakeAnomaly(3)]));

  List<Override> overrides() => [fakeSession(), anomalyRepositoryProvider.overrideWithValue(repo)];

  Future<void> pumpScreen(WidgetTester tester, double width, {double height = 900}) =>
      pumpAtWidth(tester, width, Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: const AnomalyWebScreen())),
          height: height, overrides: overrides());

  Future<void> openFirstAt1440(WidgetTester tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('Ana1 Dossou'));
    await tester.pumpAndSettle();
    // Les boutons de décision sont en bas du panneau : on les fait défiler à l'écran.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Valider'));
    await tester.pumpAndSettle();
  }

  FilledButton rejectDialogButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));

  testWidgets('1440 px: table with the spec columns, OPEN filter', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(DataTable), findsOneWidget);
    for (final c in ['Employé', 'Site', 'Pointé depuis le téléphone de', 'Date / heure', 'Entrée/Sortie', 'Statut']) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.text('Siège Cotonou'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2)); // an2 et an3 sans site
    expect(repo.listStatuses, ['OPEN']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 px: cards, no overflow', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    expect(find.byType(AnomalyCard), findsNWidgets(3));
    expect(find.textContaining('Site : Siège Cotonou'), findsOneWidget);
    expect(find.textContaining('Site : —'), findsNWidgets(2));
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail shows the selfie in an Image', (tester) async {
    await openFirstAt1440(tester);
    expect(find.byType(AnomalyDetailView), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.descendant(of: find.byType(AnomalyDetailView), matching: find.text('Site')), findsOneWidget);
    expect(find.descendant(of: find.byType(AnomalyDetailView), matching: find.text('Siège Cotonou')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail without a photo shows a placeholder', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('Ana2 Dossou'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Aucune photo'), findsOneWidget);
    expect(find.descendant(of: find.byType(AnomalyDetailView), matching: find.text('—')), findsOneWidget);
  });

  testWidgets('reject button is disabled with an empty comment, enabled with text', (tester) async {
    await openFirstAt1440(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rejeter'));
    await tester.pumpAndSettle();
    expect(rejectDialogButton(tester).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '   ');
    await tester.pump();
    expect(rejectDialogButton(tester).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Photo floue');
    await tester.pump();
    expect(rejectDialogButton(tester).onPressed, isNotNull);
  });

  testWidgets('rejecting sends the comment and the anomaly leaves the list', (tester) async {
    await openFirstAt1440(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rejeter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Photo floue');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(repo.decisions.single, (id: 'an1', decision: 'reject', comment: 'Photo floue'));
    expect(find.text('Ana1 Dossou'), findsNothing);
    expect(find.byType(AnomalyDetailView), findsNothing);
  });

  testWidgets('validating with a comment sends it', (tester) async {
    await openFirstAt1440(tester);
    await tester.enterText(find.byType(TextField), 'RAS');
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await tester.pumpAndSettle();
    expect(repo.decisions.single, (id: 'an1', decision: 'validate', comment: 'RAS'));
    expect(find.text('Ana1 Dossou'), findsNothing);
  });

  testWidgets('an ApiException is shown in a SnackBar', (tester) async {
    repo.decisionError = alreadyDecided();
    await openFirstAt1440(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Cette anomalie a déjà été traitée.')), findsOneWidget);
    expect(find.text('Ana1 Dossou'), findsWidgets);
  });

  testWidgets('360 px: a card opens the page, which closes after a decision', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    await tester.tap(find.byType(AnomalyCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(AnomalyDetailView), findsOneWidget);
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, 'Valider'), 200, scrollable: find.descendant(of: find.byType(AnomalyDetailView), matching: find.byType(Scrollable)).first);
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Anomalie introuvable'), findsNothing, reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    expect(find.byType(AnomalyDetailView), findsNothing);
    expect(find.byType(AnomalyCard), findsNWidgets(2));
  });
}
