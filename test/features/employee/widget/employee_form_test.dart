import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_model.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/widgets/employee_form.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  late Employee? created;

  List<Override> overrides({FakeUserRepository? users}) => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(users ?? FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ];

  Future<void> pumpForm(WidgetTester tester, {FakeUserRepository? users}) => pumpAtWidth(
        tester,
        800,
        Scaffold(body: EmployeeForm(onCreated: (e) => created = e)),
        height: 1400,
        overrides: overrides(users: users),
      );

  Future<void> choose(WidgetTester tester, String fieldLabel, String option) async {
    await tester.tap(find.widgetWithText(InputDecorator, fieldLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
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
    expect(find.text('Champ obligatoire'), findsNWidgets(3)); // utilisateur, annuaire, matricule
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone (facultatif)'), '123');
    await submit(tester);
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

  testWidgets('a valid form sends the draft and reports the new employee', (tester) async {
    await pumpForm(tester);
    await choose(tester, 'Utilisateur', 'Ana Dossou — ana@pointage.bj');
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await choose(tester, 'Site (facultatif)', 'Siège Cotonou');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), ' EMP0000099 ');
    await submit(tester);
    expect(repo.lastDraft?.userId, 'usr1');
    expect(repo.lastDraft?.directoryId, 'dir1');
    expect(repo.lastDraft?.siteId, 'sit1');
    expect(repo.lastDraft?.employeeNumber, 'EMP0000099');
    expect(repo.lastDraft?.phone, isNull);
    expect(created?.employeeNumber, 'EMP0000099');
  });

  testWidgets('a backend refusal stays in the form', (tester) async {
    repo.createError = ApiException('Ce matricule est déjà utilisé.', status: 409);
    await pumpForm(tester);
    await choose(tester, 'Utilisateur', 'Ana Dossou — ana@pointage.bj');
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP0000099');
    await submit(tester);
    expect(find.text('Ce matricule est déjà utilisé.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('options that failed to load can be retried and block the submit', (tester) async {
    await pumpForm(tester, users: FakeUserRepository(error: ApiException('Erreur serveur (500)', status: 500)));
    expect(find.text('Chargement impossible'), findsOneWidget);
    await choose(tester, 'Annuaire', 'Direction générale (DG)');
    await tester.enterText(find.widgetWithText(TextFormField, 'Matricule'), 'EMP0000099');
    await submit(tester);
    expect(tester.takeException(), isNull);
    expect(repo.lastDraft, isNull);
    expect(find.text('Choisissez un utilisateur.'), findsOneWidget);
  });
}
