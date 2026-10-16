import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/widgets/pagination_bar.dart';
import 'package:pointage/core/widgets/search_field.dart';
import 'package:pointage/core/widgets/state_views.dart';

import '../../helpers/pump.dart';

void main() {
  testWidgets('PaginationBar shows the range and disables missing directions', (tester) async {
    var next = 0;
    await pumpAtWidth(tester, 360, Scaffold(body: PaginationBar(offset: 20, count: 20, total: 45, onNext: () => next++)));
    expect(find.text('21–40 sur 45'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
    await tester.tap(find.byTooltip('Page suivante'));
    expect(next, 1);
  });

  testWidgets('SearchField waits 300 ms of silence, then sends the trimmed text once', (tester) async {
    final sent = <String>[];
    await pumpAtWidth(tester, 360, Scaffold(body: SearchField(label: 'Matricule', onChanged: sent.add)));
    await tester.enterText(find.byType(TextField), 'EMP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), ' EMP0000001 ');
    await tester.pump(const Duration(milliseconds: 299));
    expect(sent, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sent, ['EMP0000001']);
  });

  testWidgets('ErrorState offers a retry', (tester) async {
    var retried = false;
    await pumpAtWidth(tester, 360, Scaffold(body: ErrorState(message: 'Boom', onRetry: () => retried = true)));
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('state views fit in a very short area', (tester) async {
    await pumpAtWidth(
      tester,
      360,
      Scaffold(body: SizedBox(height: 80, child: ErrorState(message: 'Boom', onRetry: () {}))),
    );
    expect(tester.takeException(), isNull);
  });
}
