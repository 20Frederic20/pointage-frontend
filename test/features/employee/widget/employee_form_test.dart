import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_form.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  late Employee? created;

  List<Override> overrides({FakeDirectoryRepository? directories}) => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        directoryRepositoryProvider.overrideWithValue(directories ?? FakeDirectoryRepository()),
      ];

  Future<void> pumpForm(WidgetTester tester, {FakeDirectoryRepository? directories, double width = 800}) =>
      pumpAtWidth(
        tester,
        width,
        Scaffold(body: EmployeeForm(onCreated: (e) => created = e)),
        height: 1600,
        overrides: overrides(directories: directories),
      );

  Future<void> choose(WidgetTester tester, String fieldLabel, String option) async {
    await tester.tap(find.widgetWithText(InputDecorator, fieldLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String fieldLabel, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, fieldLabel), text);

  Future<void> fillAccount(WidgetTester tester) async {
    await type(tester, 'Email', ' ana@pointage.bj ');
    await type(tester, 'Prénom', ' Ana ');
    await type(tester, 'Nom', 'Dossou');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Créer'));
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeEmployeeRepository();
    created = null;
  });

  testWidgets('required fields and lengths are checked before sending', (tester) async {
    await pumpForm(tester);
    await submit(tester);
    expect(find.text('Champ obligatoire'), findsNWidgets(5)); // email, prénom, nom, annuaire, matricule
    await type(tester, 'Email', 'ana@');
    await type(tester, 'Mot de passe (facultatif)', 'court');
    await type(tester, 'Matricule', 'EMP1');
    await type(tester, 'Téléphone (facultatif)', '123');
    await submit(tester);
    expect(find.text('Email invalide'), findsOneWidget);
    expect(find.text('Au moins 8 caractères'), findsOneWidget);
    expect(find.text('Entre 10 et 20 caractères'), findsNWidgets(2));
    expect(repo.lastDraft, isNull);
  });

  testWidgets('the site list waits for a directory', (tester) async {
    await pumpForm(tester);
    expect(find.text("Choisissez d'abord un annuaire"), findsOneWidget);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    expect(find.text("Choisissez d'abord un annuaire"), findsNothing);
    expect(find.text('Site principal'), findsOneWidget);
  });

  testWidgets('a valid form sends the account and the employee together', (tester) async {
    await pumpForm(tester);
    await fillAccount(tester);
    await type(tester, 'Mot de passe (facultatif)', 's3cret-pass');
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await choose(tester, 'Site (facultatif)', 'Siège Cotonou');
    await type(tester, 'Matricule', ' EMP0000099 ');
    await submit(tester);
    final draft = repo.lastDraft;
    expect(draft?.email, 'ana@pointage.bj');
    expect(draft?.firstName, 'Ana');
    expect(draft?.lastName, 'Dossou');
    expect(draft?.password, 's3cret-pass');
    expect(draft?.directoryId, 'dir1');
    expect(draft?.siteId, 'sit1');
    expect(draft?.employeeNumber, 'EMP0000099');
    expect(draft?.phone, isNull);
    expect(created?.employeeNumber, 'EMP0000099');
  });

  testWidgets('without a password the account logs in with an emailed code', (tester) async {
    await pumpForm(tester);
    await fillAccount(tester);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await type(tester, 'Matricule', 'EMP0000099');
    await submit(tester);
    expect(repo.lastDraft?.password, isNull);
  });

  testWidgets('a backend refusal stays in the form', (tester) async {
    repo.createError = ApiException('Cet email est déjà utilisé.', status: 409);
    await pumpForm(tester);
    await fillAccount(tester);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await type(tester, 'Matricule', 'EMP0000099');
    await submit(tester);
    expect(find.text('Cet email est déjà utilisé.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('directories that failed to load can be retried and block the submit', (tester) async {
    final directories = FakeDirectoryRepository(error: ApiException('Erreur serveur (500)', status: 500));
    await pumpForm(tester, directories: directories);
    expect(find.text('Chargement impossible'), findsOneWidget);
    await fillAccount(tester);
    await type(tester, 'Matricule', 'EMP0000099');
    await submit(tester);
    expect(tester.takeException(), isNull);
    expect(repo.lastDraft, isNull);
    expect(find.text('Choisissez un annuaire.'), findsOneWidget);

    directories.error = null;
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Chargement impossible'), findsNothing);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    expect(find.text('Direction générale (DG)'), findsOneWidget);
  });

  testWidgets('the form fits a 360 px phone, dropdown open', (tester) async {
    await pumpForm(tester, width: 360);
    await tester.tap(find.widgetWithText(InputDecorator, 'Annuaire'));
    await tester.pumpAndSettle();
    expect(find.text('Direction générale (DG)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Actif » is on by default', (tester) async {
    await pumpAtWidth(tester, 800, Scaffold(body: EmployeeForm(onCreated: (_) {})), overrides: [
      fakeSession(),
      employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository()),
      directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
    ]);
    final active = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Actif'));
    expect(active.value, isTrue);
  });
}
