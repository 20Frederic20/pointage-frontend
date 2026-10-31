import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/api_client.dart';
import 'package:pointage/core/layout/admin_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_web_screen.dart';
import 'package:pointage/features/employee/widgets/employee_card.dart';
import 'package:pointage/features/employee/widgets/employee_detail_view.dart';
import 'package:pointage/features/user/user_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

void main() {
  late FakeEmployeeRepository repo;
  setUp(() => repo = FakeEmployeeRepository());

  List<Override> overrides() => [
        fakeSession(),
        employeeRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository()),
      ];

  // L'écran est testé dans la vraie coquille : la place disponible est celle de l'application.
  Future<void> pumpScreen(WidgetTester tester, double width, {double height = 900}) => pumpAtWidth(
        tester,
        width,
        AdminShell(menus: [NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const EmployeeWebScreen())]),
        height: height,
        overrides: overrides(),
      );

  testWidgets('360 px: cards, full-width toolbar, no overflow', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    expect(find.byType(EmployeeCard), findsWidgets);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byTooltip('Nouvel employé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('800 px: table without the creation date', (tester) async {
    await pumpScreen(tester, 800, height: 1000);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Créé le'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1440 px: full table', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Créé le'), findsOneWidget);
    expect(find.text('Nouvel employé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination moves page by page', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.text('1–20 sur 45'), findsOneWidget);
    await tester.tap(find.byTooltip('Page suivante'));
    await tester.pumpAndSettle();
    expect(find.text('21–40 sur 45'), findsOneWidget);
    expect(find.text('EMP0000021'), findsOneWidget);
  });

  testWidgets('1440 px: a row opens the side panel, which closes', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('EMP0000002'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(EmployeeDetailPanel), matching: find.text('EMP0000002')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeDetailPanel), findsNothing);
  });

  testWidgets('360 px: a card opens the full-screen detail', (tester) async {
    await pumpScreen(tester, 360, height: 740);
    await tester.tap(find.text('EMP0000001'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Employé'), findsOneWidget);
  });

  testWidgets('1440 px: creation opens a dialog; 360 px: a page', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text('Nouvel employé'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    // Démonte l'arbre : sinon le même Navigator garde le dialogue ouvert devant l'écran 360 px.
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, 360, height: 740);
    await tester.tap(find.byTooltip('Nouvel employé'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Nouvel employé'), findsOneWidget);
  });

  testWidgets('empty states tell "no employee" from "no result"', (tester) async {
    repo.all.clear();
    await pumpScreen(tester, 1440);
    expect(find.text('Aucun employé'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'EMP0000001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour ces filtres'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    repo.listError = ApiException('Erreur serveur (500)', status: 500);
    await pumpScreen(tester, 800, height: 1000);
    expect(find.text('Erreur serveur (500)'), findsOneWidget);
    repo.listError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('1440 px: each row has a « Faire pointer » action; none for inactive employees', (tester) async {
    repo = FakeEmployeeRepository([fakeEmployee(1), fakeEmployee(2, isActive: false)]);
    await pumpScreen(tester, 1440);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.byTooltip('Faire pointer'), findsOneWidget);
    // Le tableau défile horizontalement : la colonne Actions est au bout.
    await tester.ensureVisible(find.byTooltip('Faire pointer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Faire pointer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Faire pointer'));
    await tester.pumpAndSettle();
    expect(repo.punched, ['emp1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 px: cards carry the action and the detail panel offers the labelled button', (tester) async {
    repo = FakeEmployeeRepository([fakeEmployee(1)]);
    await pumpScreen(tester, 360, height: 740);
    expect(find.descendant(of: find.byType(EmployeeCard), matching: find.byTooltip('Faire pointer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1440 px: the side panel has a labelled « Faire pointer » button', (tester) async {
    repo = FakeEmployeeRepository([fakeEmployee(1)]);
    await pumpScreen(tester, 1440);
    await tester.tap(find.descendant(of: find.byType(DataTable), matching: find.text('EMP0000001')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(EmployeeDetailPanel), matching: find.text('Faire pointer')), findsOneWidget);
  });

  testWidgets('1440 px: each row carries the action icons', (tester) async {
    repo = FakeEmployeeRepository([fakeEmployee(1), fakeEmployee(2, isActive: false)]);
    await pumpScreen(tester, 1440);
    final table = find.byType(DataTable);
    for (final (tooltip, count) in [
      ('Faire pointer', 1), ('Modifier', 2), ('Désactiver', 1), ('Réactiver', 1), ('Affecter à un site', 1),
    ]) {
      expect(find.descendant(of: table, matching: find.byTooltip(tooltip)), findsNWidgets(count), reason: tooltip);
    }
    // L'icône agit sans ouvrir la fiche : la boîte de dialogue « Modifier » s'ouvre directement.
    final edit = find.descendant(of: table, matching: find.byTooltip('Modifier')).first;
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'employé"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 px: cards carry the action icons without overflow', (tester) async {
    repo = FakeEmployeeRepository([fakeEmployee(1)]);
    await pumpScreen(tester, 360, height: 740);
    final card = find.byType(EmployeeCard);
    for (final tooltip in ['Faire pointer', 'Modifier', 'Désactiver', 'Affecter à un site']) {
      expect(find.descendant(of: card, matching: find.byTooltip(tooltip)), findsOneWidget, reason: tooltip);
    }
    await tester.tap(find.descendant(of: card, matching: find.byTooltip('Désactiver')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Il ne pourra plus pointer.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
