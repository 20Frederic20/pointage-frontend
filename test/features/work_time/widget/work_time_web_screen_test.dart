import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/directory/directory_controller.dart';
import 'package:pointage/features/work_time/period.dart';
import 'package:pointage/features/work_time/screens/work_time_web_screen.dart';
import 'package:pointage/features/work_time/work_time_controller.dart';
import 'package:pointage/features/work_time/work_time_model.dart';
import 'package:pointage/features/work_time/work_time_repository.dart';
import 'package:pointage/features/work_time/widgets/time_entry_card.dart';
import 'package:pointage/features/work_time/widgets/work_time_days_view.dart';
import 'package:pointage/features/work_time/widgets/work_time_summary_card.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';
import '../../../helpers/work_time_fakes.dart';

void main() {
  late FakeWorkTimeRepository repo;
  late List<({String filename, String mimeType, int size})> saved;
  setUp(() {
    repo = FakeWorkTimeRepository();
    saved = [];
  });

  List<Override> overrides() => [
        fakeSession(),
        workTimeRepositoryProvider.overrideWithValue(repo),
        allDirectoriesProvider.overrideWith((ref) async => []),
        saveFileProvider.overrideWithValue((Uint8List bytes, String filename, String mimeType) =>
            saved.add((filename: filename, mimeType: mimeType, size: bytes.length))),
      ];

  Future<void> pumpScreen(WidgetTester tester, double width, {double height = 900}) => pumpAtWidth(
      tester, width, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: WorkTimeWebScreen())),
      height: height, overrides: overrides());

  Future<void> openWorkTimeTab(WidgetTester tester) async {
    await tester.tap(find.text('Temps de travail'));
    await tester.pumpAndSettle();
  }

  testWidgets('the default period is today and the first load uses it', (tester) async {
    await pumpScreen(tester, 1440);
    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(repo.entryCalls.single.period, Period.today());
    expect(find.byType(DataTable), findsOneWidget);
    for (final label in ['Compté', 'En attente', 'Normal', 'Par un responsable']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('switching tabs keeps the period', (tester) async {
    await pumpScreen(tester, 1440);
    await tester.tap(find.text("Aujourd'hui"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hier').last); // « Cette semaine » vaut « Aujourd'hui » le lundi
    await tester.pumpAndSettle();
    expect(repo.entryCalls.last.period, Period.yesterday());
    await openWorkTimeTab(tester);
    expect(repo.reportCalls.last.period, Period.yesterday());
    expect(find.text('Hier'), findsOneWidget);
  });

  testWidgets('the summary shows the to-check and not-calculated counts, a tap opens the days', (tester) async {
    await pumpScreen(tester, 1440);
    await openWorkTimeTab(tester);
    for (final c in ['Présences', 'Absences', 'Retards', 'Heures travaillées', 'Jours avec heures supp.',
        'Jours à vérifier', 'Jours non calculés']) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.text('25:30'), findsNWidgets(2));
    final row1 = find.ancestor(of: find.text('Ana1 Dossou'), matching: find.byType(DataTable));
    expect(row1, findsOneWidget);
    expect(find.text('2'), findsOneWidget); // à vérifier, emp1
    expect(find.text('3').evaluate().length, greaterThanOrEqualTo(1)); // non calculés, emp2
    await tester.tap(find.text('Ana1 Dossou'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkTimeDaysView), findsOneWidget);
    expect(find.text('Présent'), findsOneWidget);
    expect(find.textContaining('Maladie'), findsOneWidget);
  });

  testWidgets('Recalculer shows the counts message and reloads', (tester) async {
    await pumpScreen(tester, 1440);
    await openWorkTimeTab(tester);
    final loads = repo.reportCalls.length;
    await tester.tap(find.text('Recalculer'));
    await tester.pumpAndSettle();
    expect(repo.recalcCalls.single.period, Period.today());
    expect(find.text('12 jours recalculés, 2 validés ignorés, 1 en échec.'), findsOneWidget);
    expect(repo.reportCalls.length, loads + 1);
  });

  testWidgets('Exporter calls the repository with the chosen format and saves the file', (tester) async {
    await pumpScreen(tester, 1440);
    await openWorkTimeTab(tester);
    await tester.tap(find.text('Exporter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF').last);
    await tester.pumpAndSettle();
    expect(repo.exportCalls.single.format, ExportFormat.pdf);
    expect(saved.single.filename, ExportFormat.pdf.filename(Period.today()));
    expect(saved.single.mimeType, 'application/pdf');
  });

  testWidgets('a backend error is shown', (tester) async {
    repo.error = periodError;
    await pumpScreen(tester, 1440);
    expect(find.text('La période ne peut pas dépasser 62 jours.'), findsOneWidget);
  });

  for (final width in responsiveWidths) {
    testWidgets('fits at $width px on both tabs', (tester) async {
      await pumpScreen(tester, width, height: width < 600 ? 740 : 900);
      if (width < 1024) {
        expect(find.byType(TimeEntryCard), findsNWidgets(2));
      }
      await openWorkTimeTab(tester);
      if (width < 1024) {
        expect(find.byType(WorkTimeSummaryCard), findsNWidgets(2));
      } else {
        expect(find.byType(DataTable), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
