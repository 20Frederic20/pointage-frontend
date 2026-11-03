import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/admin/admin_app.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';
import 'package:pointage/features/anomaly/screens/anomaly_web_screen.dart';
import 'package:pointage/features/anomaly/widgets/anomaly_detail_view.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/employee/screens/employee_detail_page.dart';
import 'package:pointage/features/user/user_repository.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

import '../helpers/anomaly_fakes.dart';
import '../helpers/directory_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/work_time_fakes.dart';

void main() {
  Future<void> pumpAdmin(WidgetTester tester, {String role = 'HR'}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fakeSession(role: role, userId: 'usr9'),
        employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryAdminRepository()),
        anomalyRepositoryProvider.overrideWithValue(FakeAnomalyRepository()),
        workTimeRepositoryProvider.overrideWithValue(FakeWorkTimeRepository()),
      ],
      retry: (_, _) => null,
      child: const AdminApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openWithCtrlK(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Finder inPalette(Finder f) => find.descendant(of: find.byKey(const ValueKey('admin-search')), matching: f);

  testWidgets('Ctrl+K opens the search; a page result navigates there', (tester) async {
    await pumpAdmin(tester);
    await openWithCtrlK(tester);
    expect(find.byKey(const ValueKey('admin-search')), findsOneWidget);
    await tester.enterText(inPalette(find.byType(TextField)), 'anom');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-search')), findsNothing);
    expect(find.byType(AnomalyWebScreen), findsOneWidget);
  });

  testWidgets('the search trigger opens it too; « Annuaires » is not offered to HR', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('Rechercher…'));
    await tester.pumpAndSettle();
    await tester.enterText(inPalette(find.byType(TextField)), 'annu');
    await tester.pumpAndSettle();
    expect(inPalette(find.text('Annuaires')), findsNothing);
    expect(inPalette(find.text('Aucun résultat.')), findsOneWidget);
  });

  testWidgets('an employee found by matricule opens their record', (tester) async {
    await pumpAdmin(tester);
    await openWithCtrlK(tester);
    await tester.enterText(inPalette(find.byType(TextField)), 'emp0000003');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(inPalette(find.text('EMP0000003')).first);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeDetailPage), findsOneWidget);
  });

  testWidgets('an open anomaly found by name opens its detail', (tester) async {
    await pumpAdmin(tester);
    await openWithCtrlK(tester);
    await tester.enterText(inPalette(find.byType(TextField)), 'ana2');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(inPalette(find.text('Ana2 Dossou')).first);
    await tester.pumpAndSettle();
    expect(find.byType(AnomalyDetailView), findsOneWidget);
  });
}
