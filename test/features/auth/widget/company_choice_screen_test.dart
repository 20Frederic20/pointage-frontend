import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/role.dart';
import 'package:pointage/features/auth/auth_repository.dart';
import 'package:pointage/features/auth/company_choice_screen.dart';

import '../../../helpers/pump.dart';

void main() {
  testWidgets('lists the companies and signs in with the chosen one', (tester) async {
    Employment? chosen;
    await pumpAtWidth(
      tester,
      360,
      CompanyChoiceScreen(
        employments: [
          Employment(employeeId: 'emp1', companyName: 'Société A', role: Role.employee),
          Employment(employeeId: 'emp2', companyName: null, role: Role.hr),
        ],
        onChoose: (e) async => chosen = e,
      ),
    );
    expect(find.text('Dans quelle entreprise voulez-vous vous connecter ?'), findsOneWidget);
    expect(find.text('Société A'), findsOneWidget);
    expect(find.text('Entreprise inconnue'), findsOneWidget);
    expect(find.text('RH'), findsOneWidget);
    await tester.tap(find.text('Entreprise inconnue'));
    await tester.pumpAndSettle();
    expect(chosen?.employeeId, 'emp2');
  });

  for (final width in responsiveWidths) {
    testWidgets('$width px: long company names fit', (tester) async {
      await pumpAtWidth(
        tester,
        width,
        CompanyChoiceScreen(
          employments: [
            Employment(
                employeeId: 'emp1',
                companyName: 'Société Béninoise de Distribution et de Services Logistiques du Littoral',
                role: Role.payroll),
          ],
          onChoose: (_) async {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
