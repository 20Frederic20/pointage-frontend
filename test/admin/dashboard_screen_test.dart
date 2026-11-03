import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/admin/admin_app.dart';
import 'package:pointage/features/anomaly/anomaly_repository.dart';
import 'package:pointage/features/anomaly/screens/anomaly_web_screen.dart';
import 'package:pointage/features/directory/directory_repository.dart';
import 'package:pointage/features/employee/employee_repository.dart';
import 'package:pointage/features/user/user_repository.dart';
import 'package:pointage/features/work_time/period.dart';
import 'package:pointage/features/work_time/work_time_model.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';

import '../helpers/anomaly_fakes.dart';
import '../helpers/directory_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/work_time_fakes.dart';

WorkTimeDay today(int n, DayState state, {Duration late = Duration.zero, bool overtime = false}) {
  final now = DateTime.now();
  return WorkTimeDay(
    employeeId: 'emp$n',
    workDate: DateTime(now.year, now.month, now.day),
    state: state,
    worked: Duration.zero,
    late: late,
    overtime: overtime,
    firstIn: null,
  );
}

void main() {
  late FakeWorkTimeRepository workTime;

  Future<void> pumpDashboard(WidgetTester tester, {double width = 1440}) async {
    workTime = FakeWorkTimeRepository(
      report: WorkTimeReport(
        summary: [fakeSummary(1), fakeSummary(2), fakeSummary(3)],
        days: [
          today(1, DayState.present, late: const Duration(minutes: 10), overtime: true),
          today(2, DayState.absent),
          today(3, DayState.notYetArrived),
        ],
      ),
    );
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fakeSession(role: 'HR', userId: 'usr9'),
        employeeRepositoryProvider.overrideWithValue(FakeEmployeeRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        directoryRepositoryProvider.overrideWithValue(FakeDirectoryAdminRepository()),
        anomalyRepositoryProvider.overrideWithValue(FakeAnomalyRepository()),
        workTimeRepositoryProvider.overrideWithValue(workTime),
      ],
      retry: (_, _) => null,
      child: const AdminApp(),
    ));
    await tester.pumpAndSettle();
  }

  int tileValue(WidgetTester tester, String label) {
    final tile = find.ancestor(of: find.text(label), matching: find.byKey(const ValueKey('dashboard-stat'))).first;
    final texts = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)));
    return int.parse(texts.map((t) => t.data).firstWhere((d) => d != null && int.tryParse(d) != null)!);
  }

  testWidgets("today's figures come from the work-time report and the open anomalies", (tester) async {
    await pumpDashboard(tester);
    expect(workTime.reportCalls.single.period, Period.today());
    expect(tileValue(tester, 'Présents'), 1);
    expect(tileValue(tester, 'Absents'), 1);
    expect(tileValue(tester, 'En retard'), 1);
    expect(tileValue(tester, 'Anomalies en attente'), 3);
    expect(find.text('1 pas encore arrivé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lists show who is late and the open anomalies, with a link', (tester) async {
    await pumpDashboard(tester);
    final late = find.ancestor(of: find.text('Retards du jour'), matching: find.byKey(const ValueKey('dashboard-late')));
    expect(find.descendant(of: late, matching: find.text('Ana1 Dossou')), findsOneWidget);
    expect(find.descendant(of: late, matching: find.text('10 min')), findsOneWidget);
    final pending = find.byKey(const ValueKey('dashboard-anomalies'));
    expect(find.descendant(of: pending, matching: find.text('Ana2 Dossou')), findsOneWidget);
    await tester.tap(find.text('Voir toutes'));
    await tester.pumpAndSettle();
    expect(find.byType(AnomalyWebScreen), findsOneWidget);
  });

  testWidgets('360 px: the dashboard fits a phone', (tester) async {
    await pumpDashboard(tester, width: 360);
    expect(find.text('Présents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
