import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/features/punch/assisted_punch_controller.dart';
import 'package:pointage/features/punch/assisted_punch_screen.dart';
import 'package:pointage/features/punch/punch_repository.dart';
import 'package:pointage/features/punch/punch_screen.dart';

import '../../../helpers/assisted_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump.dart';

// PNG 1x1 valide pour Image.memory.
const _png = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  testWidgets('PunchScreen offers « Pointer pour un collègue »', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      400,
      const PunchScreen(),
      overrides: [
        fakeSession(),
        punchRepositoryProvider.overrideWithValue(FakePunchRepository()),
      ],
      settle: false,
    );
    expect(find.text('Pointer pour un collègue'), findsOneWidget);
  });

  testWidgets('walks the whole flow', (tester) async {
    final repo = FakePunchRepository();
    var picks = 0;
    await pumpAtWidth(
      tester,
      400,
      const PunchScreen(),
      overrides: [
        fakeSession(),
        punchRepositoryProvider.overrideWithValue(repo),
        selfiePickerProvider.overrideWithValue(() async {
          picks++;
          return (_png, 'image/png');
        }),
      ],
      settle: false,
    );
    await tester.tap(find.text('Pointer pour un collègue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'EMP0000002');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Dossou'), findsOneWidget);

    // « Modifier » revient à la saisie
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifier'), findsOneWidget);
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("C'est moi"));
    await tester.pumpAndSettle();
    expect(find.text('Prendre le selfie'), findsOneWidget);
    expect(find.text('Pointer'), findsNothing);
    await tester.tap(find.text('Prendre le selfie'));
    await tester.pumpAndSettle();
    expect(picks, 1);

    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    expect(picks, 2);

    await tester.tap(find.text('Pointer'));
    await tester.pumpAndSettle();
    expect(repo.sent.single.contentType, 'image/png');
    expect(
      find.textContaining(
        'Pointage enregistré pour Ana Dossou — en attente de validation',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Entrée'), findsOneWidget);
    expect(find.textContaining('08:05'), findsOneWidget);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistedPunchScreen), findsNothing);
    expect(find.text('POINTER'), findsOneWidget);
  });

  testWidgets('unknown matricule shows the error and stays on the form', (
    tester,
  ) async {
    final repo = FakePunchRepository()..lookupError = notFound();
    await pumpAtWidth(
      tester,
      400,
      const AssistedPunchScreen(),
      overrides: [
        fakeSession(),
        punchRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.enterText(find.byType(TextField), 'EMP0000099');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Matricule introuvable.'), findsOneWidget);
    expect(find.text('Vérifier'), findsOneWidget);
  });

  testWidgets('no selfie yet: no « Pointer » button', (tester) async {
    await pumpAtWidth(
      tester,
      400,
      const AssistedPunchScreen(),
      overrides: [
        fakeSession(),
        punchRepositoryProvider.overrideWithValue(FakePunchRepository()),
      ],
    );
    expect(find.widgetWithText(FilledButton, 'Pointer'), findsNothing);
  });

  testWidgets('a failing camera shows a message and stays on the selfie step', (tester) async {
    await pumpAtWidth(tester, 400, const AssistedPunchScreen(), overrides: [
      fakeSession(),
      punchRepositoryProvider.overrideWithValue(FakePunchRepository()),
      selfiePickerProvider.overrideWithValue(() async => throw PlatformException(code: 'camera_access_denied')),
    ]);
    await tester.enterText(find.byType(TextField), 'EMP0000002');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("C'est moi"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prendre le selfie'));
    await tester.pumpAndSettle();
    expect(find.text("Autorisez l'appareil photo pour prendre le selfie."), findsOneWidget);
    expect(find.text('Prendre le selfie'), findsOneWidget);
  });
}
