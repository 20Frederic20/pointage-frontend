import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/theme.dart';

/// Largeurs de référence de la responsivité web : téléphone, tablette, desktop.
const responsiveWidths = [360.0, 800.0, 1440.0];

/// Affiche [child] dans une fenêtre de [width] × [height] px. Les débordements
/// (RenderFlex overflowed) font échouer le test automatiquement.
/// Thème sans Google Fonts : pas d'accès réseau en test.
Future<void> pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child, {
  double height = 900,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp(theme: ThemeData(colorSchemeSeed: AppColors.green), home: child),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
