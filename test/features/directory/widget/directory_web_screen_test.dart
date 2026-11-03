import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/directory/screens/directory_web_screen.dart';
import 'package:pointage/features/directory/widgets/site_map.dart';

import '../../../helpers/directory_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeDirectoryAdminRepository repo;
  setUp(() => repo = FakeDirectoryAdminRepository());

  List<Override> overrides() => [
        fakeSession(role: 'ADMIN'),
        directoryRepositoryProvider.overrideWithValue(repo),
        mapTilesProvider.overrideWithValue(null), // pas de tuiles réseau en test
      ];

  Future<void> pumpScreen(WidgetTester tester, double width, {double height = 900}) => pumpAtWidth(
      tester, width, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: DirectoryWebScreen())),
      height: height, overrides: overrides());

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the tree nests companies, services and sites, principal tagged', (tester) async {
    await pumpScreen(tester, 1440);
    for (final label in ['Société A', 'Agence Nord', 'Société B', 'Siège A', 'Annexe A']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('principal'), findsWidgets);
    expect(find.text('+ Entreprise'), findsOneWidget);
  });

  testWidgets('« + Entreprise » creates a company that appears in the tree', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('+ Entreprise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Société C');
    await tester.enterText(find.widgetWithText(TextFormField, 'Code'), 'SC');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create Société C'));
    expect(find.text('Société C'), findsWidgets);
  });

  testWidgets('deactivating a company shows its service as blocked', (tester) async {
    await pumpScreen(tester, 1440);
    await select(tester, 'Société A');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Désactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Désactiver')); // confirmation
    await tester.pumpAndSettle();
    expect(repo.calls, contains('deactivate a'));
    expect(find.text('désactivé'), findsWidgets);
    expect(find.text('bloqué par Société A'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Réactiver'), findsOneWidget);
  });

  testWidgets('deactivating the principal site shows the message, nothing changes', (tester) async {
    await pumpScreen(tester, 1440);
    await select(tester, 'Siège A');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Désactiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Désactiver'));
    await tester.pumpAndSettle();
    expect(find.text("Le site principal ne peut pas être désactivé : rendez d'abord un autre site principal."),
        findsOneWidget);
    expect(repo.sitesByDirectory['a']!.first.active, isTrue);
  });

  testWidgets('« + Site »: Enregistrer waits for a name and a point; a tap on the map sets it', (tester) async {
    await pumpScreen(tester, 1440);
    await select(tester, 'Société B');
    await tester.tap(find.widgetWithText(OutlinedButton, '+ Site'));
    await tester.pumpAndSettle();
    FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer'));
    expect(save().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Siège B');
    await tester.pump();
    expect(save().onPressed, isNull); // pas encore de point
    await tester.tapAt(tester.getCenter(find.byKey(const Key('site-form-map'))));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(save().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();
    final created = repo.createdSites.single;
    expect((created['directoryId'], created['name']), ('b', 'Siège B'));
    expect(created['latitude'] as double, closeTo(6.3654, 0.05)); // centre par défaut : Cotonou
    expect(created['longitude'] as double, closeTo(2.4183, 0.05));
  });

  for (final width in responsiveWidths) {
    testWidgets('fits at $width px, detail opens', (tester) async {
      await pumpScreen(tester, width, height: width < 600 ? 740 : 900);
      await select(tester, 'Agence Nord');
      expect(find.widgetWithText(OutlinedButton, '+ Service'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
