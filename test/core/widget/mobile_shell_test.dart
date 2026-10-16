import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/mobile_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';

import '../../helpers/pump.dart';

void main() {
  testWidgets('bottom bar switches tabs and builds a tab only once visited', (tester) async {
    await pumpAtWidth(
      tester,
      390,
      MobileShell(tabs: [
        NavItem(label: 'Pointage', icon: Icons.fingerprint, builder: (_) => const Text('Page pointage')),
        NavItem(label: 'Employés', icon: Icons.badge_outlined, builder: (_) => const Text('Page employés')),
      ]),
      height: 800,
    );
    expect(find.text('Page pointage'), findsOneWidget);
    expect(find.text('Page employés', skipOffstage: false), findsNothing);
    await tester.tap(find.text('Employés'));
    await tester.pumpAndSettle();
    expect(find.text('Page employés'), findsOneWidget);
  });
}
