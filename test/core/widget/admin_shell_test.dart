import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/admin_shell.dart';
import 'package:pointage/core/layout/nav_item.dart';
import 'package:pointage/features/auth/session_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

final menus = [
  NavItem(label: 'Menu A', icon: Icons.badge_outlined, builder: (_) => const Text('Page A')),
  NavItem(label: 'Menu B', icon: Icons.schedule, builder: (_) => const Text('Page B')),
];

Future<void> pumpShell(WidgetTester tester, double width, {List<NavItem>? items}) =>
    pumpAtWidth(tester, width, AdminShell(menus: items ?? menus), overrides: [fakeSession()]);

void main() {
  testWidgets('phone: app bar with a drawer', (tester) async {
    await pumpShell(tester, 360);
    expect(find.text('Page A'), findsOneWidget);
    expect(find.byKey(const Key('admin-side-menu')), findsNothing);
    expect(find.byKey(const Key('admin-rail')), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Menu B'), findsOneWidget);
  });

  testWidgets('tablet: icon rail with tooltips', (tester) async {
    await pumpShell(tester, 800);
    expect(find.byKey(const Key('admin-rail')), findsOneWidget);
    expect(find.byKey(const Key('admin-side-menu')), findsNothing);
    await tester.tap(find.byTooltip('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
  });

  testWidgets('desktop: side menu with labels', (tester) async {
    await pumpShell(tester, 1440);
    expect(find.byKey(const Key('admin-side-menu')), findsOneWidget);
    await tester.tap(find.text('Menu B'));
    await tester.pumpAndSettle();
    expect(find.text('Page B'), findsOneWidget);
  });

  testWidgets('a single menu works at every width', (tester) async {
    for (final width in responsiveWidths) {
      await pumpShell(tester, width, items: [menus.first]);
      expect(find.text('Page A'), findsOneWidget, reason: '$width px');
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });

  testWidgets('desktop: logout ends the session', (tester) async {
    await pumpShell(tester, 1440);
    await tester.tap(find.byTooltip('Se déconnecter'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AdminShell)));
    expect(container.read(sessionProvider).value, isNull);
  });

  testWidgets('content is capped at 1400 px on very wide screens', (tester) async {
    await pumpAtWidth(tester, 2400, AdminShell(menus: menus), overrides: [fakeSession()]);
    final page = tester.getRect(find.byKey(const Key('admin-page')));
    expect(page.width, lessThanOrEqualTo(1400));
  });
}
